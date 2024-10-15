#!/usr/bin/env ruby

# source: https://younes.codes/posts/what-is-rack

require 'socket'
require 'stringio'

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

  private

  attr_reader :socket
end

class DummyRackServer
  attr_reader :hostname, :port

  def initialize(hostname: 'localhost', port: 9292)
    @hostname = hostname
    @port = port
  end

  def run
    server = TCPServer.new(hostname, port)
    begin
      loop do
        client = server.accept
        begin
          request_line, headers, body = DummyHttpRequestReader.new(socket: client).read
          client.write(build_response)
        ensure
          client.close
        end
      end
    ensure
      server.close
    end
  end

  private

  def build_response
    <<~EOF
      HTTP/1.1 200 OK

      <html><body>hello, world</body></html>
    EOF
  end
end

dummy_rack_server = DummyRackServer.new(
  hostname: 'localhost',
  port: 9292
)

dummy_rack_server.run
