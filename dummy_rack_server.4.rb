#!/usr/bin/env ruby

# source: https://younes.codes/posts/what-is-rack

require 'socket'
require 'stringio'
require 'logger'

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
    # > The environment must be an unfrozen instance of Hash that includes CGI-like headers. The Rack application is free to modify the environment.
    # > The environment is required to include these variables (adopted from PEP 333), except when they’d be empty, but see below.
    # Source: https://github.com/rack/rack/blob/main/SPEC.rdoc#the-environment-
    # PEP 333: https://peps.python.org/pep-0333/
    env = {
      'REQUEST_METHOD' => request.request_method, # GET, POST, PATCH, ...
      'rack.url_scheme' => 'http', # In real-life, it depends on the request (http, https, ws, ...)
      'REMOTE_ADDR' => remote_addr,

      # The following variables should permit the reconstruction of the full URL. See https://peps.python.org/pep-0333/#url-reconstruction
      'REQUEST_PATH' => request.path,
      'PATH_INFO' => request.url,
      'QUERY_STRING' => request.query_string.to_s,
      'SERVER_PROTOCOL' => request.http_protocol, # HTTP/1.1
      'SCRIPT_NAME' => '',
      'SERVER_NAME' => hostname,
      'SERVER_PORT' => port.to_s,

      # Used, for instance, for Websocket connections. Hijacking spec: https://github.com/rack/rack/blob/main/SPEC.rdoc#hijacking-
      'rack.hijack?' => false,

      # IO objects
      'rack.input' => input_stream, # Allows Rack apps to read the body of the request
      'rack.logger' => logger,
      'rack.errors' => errors_stream,
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

  STATUS_MESSAGE = {
    200 => 'OK',
    201 => 'CREATED',
    404 => 'NOT FOUND',
    422 => 'UNPROCESSABLE ENTITY',
    500 => 'INTERNAL ERROR'
    # ...
  }

  def build_response(env:, status: 200, headers: [], body: [])
    response = [
      [
        env.fetch('SERVER_PROTOCOL', 'HTTP/1.1'),
        status,
        STATUS_MESSAGE.fetch(status, 'UNKNOWN')
      ].join(' ')
    ]
    headers.each { |name, value| response.push("#{name}: #{value}") }
    response.push('')
    response.concat(body)
    response.join("\r\n")
  end
end

dummy_rack_application = -> (env) do
  status_code = 200
  headers = {
    'content-type' => 'text/html; charset=utf-8',
    'content-location' => 'https://younes.codes'
  }
  body = [
    '<html><body>',
    'hello, world',
    '</body></html>'
  ]
  [status_code, headers, body]
end

dummy_rack_server = DummyRackServer.new(
  hostname: 'localhost',
  port: 9292,
  rack_application: dummy_rack_application
)

dummy_rack_server.run
