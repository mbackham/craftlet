module Etl
  module CleanRules
    class EnumCheck
      def initialize(rule)
        @rule    = rule
        @allowed = Array(rule.params['allowed'])
      end

      def apply(record, field)
        value = record[field]
        return { value: value, action: nil } if value.nil?

        if @allowed.include?(value.to_s)
          { value: value, action: nil }
        else
          case @rule.action
          when 'fill_default'
            default = @rule.params['default']
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
end
