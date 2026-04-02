module Etl
  class DataCleaner
    STRATEGY_MAP = {
      'null_check'   => CleanRules::NullCheck,
      'range_check'  => CleanRules::RangeCheck,
      'format_check' => CleanRules::FormatCheck,
      'enum_check'   => CleanRules::EnumCheck,
      'custom'       => CleanRules::CustomCheck
    }.freeze

    attr_reader :cleaned_count

    def initialize(source_table:, batch_id:)
      @source_table  = source_table
      @batch_id      = batch_id
      @rules         = EtlCleanRule.active.for_table(source_table).ordered
      @cleaned_count = 0
    end

    # Returns [clean_records, skipped_count]
    def clean(records)
      return [records, 0] if @rules.empty?

      clean_records = []
      skipped = 0

      records.each do |record|
        result = apply_rules(record)
        if result[:skip]
          skipped += 1
          @cleaned_count += 1
        else
          clean_records << result[:record]
        end
      end

      [clean_records, skipped]
    end

    private

    def apply_rules(record)
      current = record.dup
      should_skip = false

      @rules.each do |rule|
        field = rule.target_field
        next unless current.key?(field) || current.key?(field.to_sym)

        strategy = STRATEGY_MAP[rule.rule_type]&.new(rule)
        next unless strategy

        field_key = current.key?(field) ? field : field.to_sym
        result = strategy.apply(current, field_key)

        next if result[:action].nil?

        log_clean_action(rule, current, field_key, result)

        if result[:action] == 'skipped'
          should_skip = true
          break
        end

        current[field_key] = result[:value]
        @cleaned_count += 1
      end

      { record: current, skip: should_skip }
    end

    def log_clean_action(rule, record, field, result)
      source_id = record['source_id'] || record['source_user_id'] || record['source_merchant_id'] || 0

      EtlCleanLog.create!(
        etl_clean_rule:   rule,
        batch_id:         @batch_id,
        source_table:     @source_table,
        source_record_id: source_id.to_i,
        field_name:       field.to_s,
        original_value:   result[:original].to_s,
        cleaned_value:    result[:cleaned].to_s,
        action_taken:     result[:action]
      )
    rescue => e
      Rails.logger.warn("[ETL][DataCleaner] Failed to log clean action: #{e.message}")
    end
  end
end
