module Etl
  class Pipeline
    SYNC_CONFIGS = [
      { source: 'orders',           extractor: Extractors::OrdersExtractor,      target: DwFactOrder,      target_table: 'dw_fact_orders' },
      { source: 'payments',         extractor: Extractors::PaymentsExtractor,    target: DwFactPayment,    target_table: 'dw_fact_payments' },
      { source: 'refunds',          extractor: Extractors::RefundsExtractor,     target: DwFactRefund,     target_table: 'dw_fact_refunds' },
      { source: 'settlements',      extractor: Extractors::SettlementsExtractor, target: DwFactSettlement, target_table: 'dw_fact_settlements' },
      { source: 'coupons',          extractor: Extractors::CouponsExtractor,     target: DwFactCoupon,     target_table: 'dw_fact_coupons' },
      { source: 'users',            extractor: Extractors::UsersExtractor,       target: DwDimUser,        target_table: 'dw_dim_users',
        unique_by: :source_user_id },
      { source: 'merchant_profiles', extractor: Extractors::MerchantsExtractor, target: DwDimMerchant,    target_table: 'dw_dim_merchants',
        unique_by: :source_merchant_id }
    ].freeze

    def self.call(source:, sync_type: 'incremental')
      new(source: source, sync_type: sync_type).run
    end

    def self.all_sources
      SYNC_CONFIGS.map { |c| c[:source] }
    end

    def self.config_for(source)
      SYNC_CONFIGS.find { |c| c[:source] == source }
    end

    def initialize(source:, sync_type: 'incremental')
      @config    = self.class.config_for(source)
      raise ArgumentError, "Unknown source: #{source}" unless @config

      @sync_type = sync_type
      @batch_id  = "#{source}_#{Time.current.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(4)}"
    end

    def run
      sync_log = create_sync_log
      started_at = Time.current

      begin
        # 1. Extract
        extractor = @config[:extractor].new(sync_log: sync_log)
        raw_records = extractor.extract_and_transform

        # 2. Clean
        cleaner = DataCleaner.new(source_table: @config[:source], batch_id: @batch_id)
        clean_records, _skipped = cleaner.clean(raw_records)

        # 3. Load
        loaded = load_records(clean_records)

        # 4. Update cursor
        cursor = raw_records.map { |r| r[:updated_at] }.compact.max

        sync_log.update!(metadata: sync_log.metadata.merge('cursor' => cursor)) if cursor
        sync_log.mark_completed!(
          extracted: raw_records.size,
          loaded: loaded,
          cleaned: cleaner.cleaned_count
        )

        Rails.logger.info("[ETL][Pipeline] #{@config[:source]}: extracted=#{raw_records.size} loaded=#{loaded} cleaned=#{cleaner.cleaned_count}")
        sync_log
      rescue => e
        sync_log.mark_failed!(e.message)
        Rails.logger.error("[ETL][Pipeline] #{@config[:source]} failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        raise
      end
    end

    private

    def create_sync_log
      EtlSyncLog.create!(
        source_table:    @config[:source],
        target_table:    @config[:target_table],
        sync_type:       @sync_type,
        status:          'running',
        batch_id:        @batch_id,
        started_at:      Time.current
      )
    end

    def load_records(records)
      return 0 if records.empty?

      unique_by = @config[:unique_by] || :source_id
      @config[:target].upsert_all(
        records,
        unique_by: unique_by,
        update_only: records.first.keys.map(&:to_s) - [unique_by.to_s]
      )
      records.size
    end
  end
end
