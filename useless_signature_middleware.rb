# source: https://younes.codes/posts/what-is-rack

class UselessSignatureMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    body << "<!-- I read https://younes.codes blog posts. It makes me happy -->"
    [status, headers, body]
  end
end
