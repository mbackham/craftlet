# frozen_string_literal: true

# 验证 BraceletConfig#bead_items 的 JSONB 数组结构
class BeadItemsValidator < ActiveModel::EachValidator
  POSITIONS = %w[main spacer focal].freeze

  def validate_each(record, attribute, value)
    unless value.is_a?(Array)
      record.errors.add(attribute, :not_an_array)
      return
    end

    value.each_with_index do |item, idx|
      validate_item(record, attribute, item, idx)
    end
  end

  private

  def validate_item(record, attribute, item, idx)
    unless item.is_a?(Hash)
      record.errors.add(attribute, :item_not_a_hash, index: idx)
      return
    end

    unless item['element_id'].present? && item['element_id'].is_a?(Integer)
      record.errors.add(attribute, :missing_element_id, index: idx)
    end

    qty = item['quantity'].to_i
    unless qty > 0
      record.errors.add(attribute, :invalid_quantity, index: idx)
    end

    pos = item['position']
    if pos.present? && !POSITIONS.include?(pos)
      record.errors.add(attribute, :invalid_position, index: idx, value: pos)
    end
  end
end
