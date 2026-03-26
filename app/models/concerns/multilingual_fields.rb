# frozen_string_literal: true

# Provides virtual attributes for JSONB multilingual fields.
# This avoids ActiveAdmin/Arbre rendering issues with JSONB Hash objects.
#
# Usage:
#   class Banner < ApplicationRecord
#     include MultilingualFields
#     multilingual :title           # => creates title_zh, title_en
#     multilingual :content         # => creates content_zh, content_en
#   end
#
#   # In ActiveAdmin form:
#   f.input :title_zh, as: :string, label: "标题 (中文)"
#   f.input :title_en, as: :string, label: "Title (English)"
#
module MultilingualFields
  extend ActiveSupport::Concern

  class_methods do
    def multilingual(*field_names)
      field_names.each do |field|
        # Define virtual accessors: field_zh, field_en
        attr_accessor :"#{field}_zh", :"#{field}_en"

        # Load from JSONB on initialize
        after_initialize do
          hash = send(field)
          if hash.is_a?(Hash)
            send(:"#{field}_zh=", hash["zh-CN"]) unless send(:"#{field}_zh").present?
            send(:"#{field}_en=", hash["en"]) unless send(:"#{field}_en").present?
          end
        end

        # Sync back to JSONB before validation
        before_validation do
          send(:"#{field}=", {
            "zh-CN" => send(:"#{field}_zh").to_s,
            "en" => send(:"#{field}_en").to_s
          })
        end
      end
    end
  end
end
