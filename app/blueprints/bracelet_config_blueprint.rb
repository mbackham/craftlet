# frozen_string_literal: true

class BraceletConfigBlueprint < BaseBlueprint
  fields :name, :status, :bead_items, :string_color_hex, :string_color_name,
         :total_beads, :wrist_size, :knot_style, :notes, :price_snapshot

  field :estimated_length_mm do |cfg|
    cfg.estimated_length_mm&.to_s
  end

  field :string_element do |cfg|
    ElementBlueprint.render_as_hash(cfg.string_element) if cfg.string_element
  end

  field :saved_at do |cfg|
    cfg.saved_at&.iso8601
  end

  field :created_at do |cfg|
    cfg.created_at&.iso8601
  end

  field :updated_at do |cfg|
    cfg.updated_at&.iso8601
  end

  # 详情视图：展开 bead_items 中每个 element 的完整信息
  view :detail do
    field :bead_items_detail do |cfg|
      element_ids = cfg.bead_items.filter_map { |i| i['element_id'] }
      elements    = Element.where(id: element_ids).index_by(&:id)

      cfg.bead_items.map do |item|
        el = elements[item['element_id']]
        item.merge(
          'element' => el ? ElementBlueprint.render_as_hash(el) : nil
        )
      end
    end
  end
end
