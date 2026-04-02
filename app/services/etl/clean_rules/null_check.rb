module Etl
  module CleanRules
    class NullCheck
      def initialize(rule)
        @rule = rule
      end

      def apply(record, field)
        value = record[field]
        return { value: value, action: nil } if value.present?

        case @rule.action
        when 'fill_default'
          default = @rule.params['default']
          { value: default, action: 'filled', original: value, cleaned: default }
        when 'skip'
          { value: nil, action: 'skipped', original: value, cleaned: nil }
        else
          { value: nil, action: 'flagged', original: value, cleaned: nil }
        end
      end
    end
  end
end
