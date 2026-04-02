class EtlSyncLog < ApplicationRecord
  STATUSES = %w[running completed failed].freeze
  SYNC_TYPES = %w[full incremental].freeze

  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :running, -> { where(status: 'running') }
  scope :for_table, ->(table) { where(source_table: table) }
  scope :recent, -> { order(created_at: :desc) }

  def duration_seconds
    return nil unless started_at && completed_at
    (completed_at - started_at).round(2)
  end

  def mark_completed!(loaded:, extracted:, cleaned:, errors: 0)
    update!(
      status: 'completed',
      loaded_count: loaded,
      extracted_count: extracted,
      cleaned_count: cleaned,
      error_count: errors,
      completed_at: Time.current
    )
  end

  def mark_failed!(message)
    update!(status: 'failed', error_message: message, completed_at: Time.current)
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[source_table target_table sync_type status extracted_count loaded_count
       cleaned_count error_count batch_id started_at completed_at created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
