#!/usr/bin/env ruby

# source: https://younes.codes/posts/what-is-rack

require 'socket'

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
          # TODO read request
          # TODO send response
        ensure
          client.close
        end
      end
    ensure
      server.close
    end
  end
end

dummy_rack_server = DummyRackServer.new(
  hostname: 'localhost',
  port: 9292
)

dummy_rack_server.run
