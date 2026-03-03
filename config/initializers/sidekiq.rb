Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }

  # 死信队列 (DLQ) 处理规范
  # 发生在此处的 job 说明所有重试机制均已耗尽
  config.death_handlers << ->(job, ex) do
    Rails.logger.error("Sidekiq Job Dead Letter: #{job['class']} (Args: #{job['args']}) - #{ex.message}")
    # STUB: 触发外部告警统 (钉钉/邮件等)
    # AdminMailer.dead_job_alert(job, ex).deliver_later
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }
end
