# frozen_string_literal: true

namespace :logs do
  desc "Tail Rails logs"
  task :rails do
    on roles(:app) do
      execute "tail -f #{shared_path}/log/production.log"
    end
  end

  desc "Tail Puma logs"
  task :puma do
    on roles(:app) do
      execute "journalctl -u craftlet-web -f"
    end
  end

  desc "Tail Sidekiq logs"
  task :sidekiq do
    on roles(:app) do
      execute "journalctl -u craftlet-sidekiq -f"
    end
  end
end

namespace :db do
  desc "Create database backup"
  task :backup do
    on roles(:db) do
      within current_path do
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        execute "pg_dump -U craftletkoma craftlet_production > /root/backups/db_#{timestamp}.sql"
        info "Database backup created: /root/backups/db_#{timestamp}.sql"
      end
    end
  end
end

namespace :app do
  desc "Check application status"
  task :status do
    on roles(:app) do
      execute "systemctl status craftlet-web --no-pager"
      execute "systemctl status craftlet-sidekiq --no-pager"
    end
  end

  desc "Clear Rails cache"
  task :clear_cache do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, :rails, "tmp:clear"
          execute :bundle, :exec, :rails, "cache:clear" rescue nil
        end
      end
    end
  end
end
