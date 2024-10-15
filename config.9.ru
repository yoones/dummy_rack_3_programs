# source: https://younes.codes/posts/what-is-rack

require_relative './ping_pong_middleware'
require_relative './useless_signature_middleware'

app = Rack::Builder.app do
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

  use PingPongMiddleware
  use UselessSignatureMiddleware
  run dummy_rack_application
end

run app
