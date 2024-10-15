#!/usr/bin/env ruby

# source: https://younes.codes/posts/what-is-rack

require 'socket'
require 'stringio'
require 'logger'
require 'rack'

# There are breaking changes with Rack 2, make sure we're requiring Rack 3!
raise 'Rack 3 required' unless Rack.release.split('.')[0] == '3'

class DummyHttpRequestReader
  def initialize(socket:)
    @socket = socket
  end

  def read
    [request_line, headers, body]
  end

  def request_line
    return @request_line if defined?(@request_line)

    @request_line = socket.gets.strip
  end

  def headers
    return @headers if defined?(@headers)

    @headers = []
    loop do
      line = socket.gets.strip
      break if line.length.zero?
      @headers << line
    end
    @headers
  end

  def body
    return @body if defined?(@body)

    buffer = StringIO.new
    begin
      loop do
        chunk = socket.read_nonblock(4096)
        buffer << chunk
        break if chunk.size < 4096
      end
    rescue IO::EAGAINWaitReadable
    end
    buffer
    @body = buffer.to_s
  end

  def request_method
    @request_method ||= request_line.split(' ')[0]
  end

  def url
    @url ||= request_line.split(' ')[1]
  end

  def path
    @path ||= url.split('?', 2)[0]
  end

  def query_string
    @query_string ||= url.split('?', 2)[1]
  end

  def http_protocol
    @request_url ||= request_line.split(' ')[2]
  end

  private

  attr_reader :socket
end

class DummyRackServer
  attr_reader :hostname, :port, :rack_application

  def initialize(hostname: 'localhost', port: 9292, rack_application:)
    @hostname = hostname
    @port = port
    @rack_application = rack_application
  end

  def run
    errors_stream = $stderr
    logger = Logger.new(STDOUT)
    server = TCPServer.new(hostname, port)
    begin
      loop do
        client = server.accept
        request = DummyHttpRequestReader.new(socket: client)
        request.read
        input_stream = StringIO.new(request.body).tap(&:binmode)
        begin
          env = build_env(
            remote_addr: remote_addr_of(client),
            request: request,
            logger: logger,
            input_stream: input_stream,
            errors_stream: errors_stream
          )
          status, headers, body = rack_application.call(env)
          response = build_response(
            env: env,
            status: status,
            headers: headers,
            body: body
          )
          client.write(response)
        ensure
          input_stream.close
          client.close
        end
      end
    ensure
      server.close
      logger.close
    end
  end

  private

  def build_env(remote_addr:, request:, logger:, input_stream:, errors_stream:)
    # Use constants defined in rack/constants.rb
    env = {
      Rack::REQUEST_METHOD => request.request_method,
      Rack::REQUEST_PATH => request.path,
      Rack::PATH_INFO => request.url,
      Rack::QUERY_STRING => request.query_string.to_s,
      Rack::SERVER_PROTOCOL => request.http_protocol,
      Rack::SCRIPT_NAME => '',
      Rack::SERVER_NAME => hostname,
      Rack::SERVER_PORT => port.to_s,
      Rack::RACK_IS_HIJACK => false,
      Rack::RACK_INPUT => input_stream,
      Rack::RACK_LOGGER => logger,
      Rack::RACK_ERRORS => errors_stream,
      Rack::RACK_TEMPFILES => [],
      Rack::RACK_URL_SCHEME => 'http',
      'REMOTE_ADDR' => remote_addr,
    }
    request.headers.each do |header|
      name, value = header.split(':', 2)
      env["HTTP_#{name.upcase}"] = value.strip
    end
    env
  end

  def remote_addr_of(client)
    client.peeraddr(false)[3]
  end

  def build_response(env:, status: 200, headers: [], body: [])
    response = [
      [
        env.fetch('SERVER_PROTOCOL', 'HTTP/1.1'),
        status,
        Rack::Utils::HTTP_STATUS_CODES.fetch(status, 'UNKNOWN')
      ].join(' ')
    ]
    # Rack 3 requires that response headers keys be lowercase. Rack::Headers does that for you:
    headers = Rack::Headers.new(headers)
    headers.each { |name, value| response.push("#{name}: #{value}") }
    response.push('')
    response.concat(body)
    response.join("\r\n")
  end
end

dummy_rack_application = Rack::Builder.parse_file('./config.ru')

dummy_rack_server = DummyRackServer.new(
  hostname: 'localhost',
  port: 9292,
  rack_application: dummy_rack_application
)

dummy_rack_server.run
