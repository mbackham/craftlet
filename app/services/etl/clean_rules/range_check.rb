module Etl
  module CleanRules
    class RangeCheck
      def initialize(rule)
        @rule = rule
        @min  = rule.params['min']&.to_d
        @max  = rule.params['max']&.to_d
      end

      def apply(record, field)
        value = record[field]
        return { value: value, action: nil } if value.nil?

        numeric = value.to_d
        in_range = (@min.nil? || numeric >= @min) && (@max.nil? || numeric <= @max)
        return { value: value, action: nil } if in_range

        case @rule.action
        when 'fill_default'
          default = @rule.params['default']&.to_d
          { value: default, action: 'filled', original: value, cleaned: default }
        when 'skip'
          { value: nil, action: 'skipped', original: value, cleaned: nil }
        else
          { value: value, action: 'flagged', original: value, cleaned: value }
        end
      end
    end
  end
end
