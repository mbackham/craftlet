# frozen_string_literal: true

ActiveAdmin.register BraceletConfig do
  menu parent: 'operations_menu', priority: 2, label: '手串方案'

  actions :index, :show

  # === Filters ===
  filter :user_id
  filter :status, as: :select, collection: BraceletConfig::STATUSES.map { |s| [s, s] }
  filter :wrist_size, as: :select, collection: BraceletConfig::WRIST_SIZES.map { |s| [s, s] }
  filter :total_beads
  filter :created_at

  # === Index ===
  index do
    id_column
    column :user do |cfg|
      cfg.user&.nickname || cfg.user_id
    end
    column :name
    column :status do |cfg|
      color = cfg.ordered? ? 'yes' : (cfg.saved? ? nil : nil)
      status_tag cfg.status, class: color
    end
    column :total_beads
    column :wrist_size
    column :created_at
    actions
  end

  # === Show ===
  show do
    attributes_table do
      row :id
      row(:user) { |cfg| cfg.user&.nickname }
      row :name
      row :status
      row :total_beads
      row :wrist_size
      row :knot_style
      row(:estimated_length_mm) { |cfg| "#{cfg.estimated_length_mm} mm" if cfg.estimated_length_mm }
      row(:string_element) { |cfg| cfg.string_element&.name }
      row :string_color_name
      row :string_color_hex
      row :notes
      row(:bead_items) { |cfg| pre { cfg.bead_items.to_json } }
      row(:price_snapshot) { |cfg| pre { cfg.price_snapshot.to_json } }
      row :saved_at
      row :created_at
      row :updated_at
    end
  end
end
