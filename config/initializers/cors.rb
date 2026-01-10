Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*" # Development: allow all origins; restrict in production.

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: ["Authorization"]
  end
end
