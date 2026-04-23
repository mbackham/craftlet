# frozen_string_literal: true

class ElementBlueprint < BaseBlueprint
  fields :name, :category, :element_type, :material_type, :finish_type,
         :color_hex, :color_name, :size_mm, :weight_g, :hole_diameter_mm,
         :hardness_level, :is_natural, :origin_region, :description,
         :oss_key, :thumbnail_key, :mesh_url, :glb_key, :tags, :status

  field :price do |el|
    el.price&.to_s
  end

  field :element_type_label do |el|
    el.element_type_label
  end

  field :material_type_label do |el|
    el.material_type_label
  end

  field :shelved_at do |el|
    el.shelved_at&.iso8601
  end

  field :created_at do |el|
    el.created_at&.iso8601
  end
end
