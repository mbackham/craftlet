module Etl
  module CleanRules
    class FormatCheck
      def initialize(rule)
        @rule    = rule
        @pattern = Regexp.new(rule.params['pattern']) if rule.params['pattern']
      end

      def apply(record, field)
        value = record[field]
        return { value: value, action: nil } if value.nil? || @pattern.nil?

        if @pattern.match?(value.to_s)
          { value: value, action: nil }
        else
          case @rule.action
          when 'skip'
            { value: nil, action: 'skipped', original: value, cleaned: nil }
          else
            { value: value, action: 'flagged', original: value, cleaned: value }
          end
        end
      end
    end
  end
end
