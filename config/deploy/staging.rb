# frozen_string_literal: true

# Staging server configuration
# TODO: 如果有 staging 服务器，请配置此文件
# server "staging.komaprogram.xyz", user: "root", roles: %w[app db web]

# For now, staging deploys to the same server but with staging branch
server "154.219.107.73", user: "root", roles: %w[app db web]

# SSH options
set :ssh_options, {
  keys: %w[~/.ssh/id_rsa],
  forward_agent: true,
  auth_methods: %w[publickey password]
}

# Server-specific settings
set :deploy_to, "/var/www/craftlet"
set :rails_env, "production"
set :branch, ENV.fetch("BRANCH", "staging")
