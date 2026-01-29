# frozen_string_literal: true

# config valid for current version and target compatible with future versions
lock "~> 3.20.0"

# Application configuration
set :application, "craftlet"
set :repo_url, "git@github.com:mbackham/craftlet.git"

# Default branch is :main
set :branch, ENV.fetch("BRANCH", "main")

# Default deploy_to directory
set :deploy_to, "/var/www/craftlet"

# Default value for :format is :airbrussh.
set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
set :pty, true

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push(".env", "config/master.key")

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push(
  "log",
  "tmp/pids",
  "tmp/cache",
  "tmp/sockets",
  "vendor/bundle",
  "public/system",
  "public/uploads",
  "storage"
)

# Default value for keep_releases is 5
set :keep_releases, 5

# Ruby version management
set :rbenv_type, :user
set :rbenv_ruby, "3.2.3"
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w[rake gem bundle ruby rails puma pumactl sidekiq sidekiqctl]

# Bundler configuration
set :bundle_flags, "--deployment --quiet"
set :bundle_path, -> { shared_path.join("vendor/bundle") }
set :bundle_without, %w[development test].join(" ")

# Rails configuration
set :rails_env, "production"
set :assets_roles, [:web, :app]

# Puma configuration
set :puma_systemctl_user, :system
set :puma_service_unit_name, "craftlet-web"

# Sidekiq configuration
set :sidekiq_systemctl_user, :system
set :sidekiq_service_unit_name, "craftlet-sidekiq"

# Custom tasks
namespace :deploy do
  desc "Restart application"
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke "puma:restart"
    end
  end

  desc "Upload environment files"
  task :upload_env do
    on roles(:app) do
      upload! ".env.production", "#{shared_path}/.env"
    end
  end

  after :publishing, :restart
end

namespace :rails do
  desc "Open Rails console on remote server"
  task :console do
    on roles(:app) do |host|
      rails_env = fetch(:rails_env, "production")
      execute_interactively(host, "cd #{current_path} && #{fetch(:rbenv_prefix)} bundle exec rails console -e #{rails_env}")
    end
  end

  desc "Run db:seed on remote server"
  task :seed do
    on roles(:db) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, :rails, "db:seed"
        end
      end
    end
  end

  def execute_interactively(host, command)
    exec "ssh -l #{host.user} #{host.hostname} -p #{host.port || 22} -t 'cd #{current_path} && #{command}'"
  end
end
