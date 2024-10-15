# source: https://younes.codes/posts/what-is-rack

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

run dummy_rack_application
