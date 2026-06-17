# frozen_string_literal: true

# Production server configuration
server "38.76.215.163", user: "deploy", roles: %w[app db web]

# SSH options
set :ssh_options, {
  keys: %w(~/.ssh/id_rsa),
  forward_agent: true,
  auth_methods: %w(publickey)
}
# Server-specific settings
set :deploy_to, "/var/www/craftlet"
set :rails_env, "production"
set :branch, "main"
