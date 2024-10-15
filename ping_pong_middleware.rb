# source: https://younes.codes/posts/what-is-rack

class PingPongMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if env[Rack::REQUEST_PATH] == '/ping'
      [200, {}, ["pong!"]]
    else
      @app.call(env)
    end
  end
end
