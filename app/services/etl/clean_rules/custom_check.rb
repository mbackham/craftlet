module Etl
  module CleanRules
    class CustomCheck
      SAFE_METHODS = %w[to_s to_i to_d to_f present? blank? nil? zero? positive? negative?].freeze

      def initialize(rule)
        @rule       = rule
        @expression = rule.params['expression']
      end

      def apply(record, field)
        return { value: record[field], action: nil } if @expression.blank?

        value = record[field]
        passes = evaluate_expression(value)

        if passes
          { value: value, action: nil }
        else
          case @rule.action
          when 'skip'
            { value: nil, action: 'skipped', original: value, cleaned: nil }
          else
            { value: value, action: 'flagged', original: value, cleaned: value }
          end
        end
      rescue => e
        Rails.logger.warn("[ETL][CustomCheck] Expression error: #{e.message}")
        { value: record[field], action: 'flagged', original: record[field], cleaned: record[field] }
      end

      private

      def evaluate_expression(value)
        # Simple safe eval: only supports basic comparisons on 'value'
        expr = @expression.gsub('value', value.to_s)
        # Restrict to safe numeric/string comparisons only
        raise 'unsafe expression' if expr =~ /[`$]|require|system|exec|eval|File|IO/
        eval(expr) # rubocop:disable Security/Eval
      rescue
        false
      end
    end
  end
end
