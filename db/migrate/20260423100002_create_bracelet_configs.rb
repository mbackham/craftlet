# frozen_string_literal: true

class CreateBraceletConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :bracelet_configs do |t|
      t.references :user, null: false, foreign_key: true

      t.string :name, null: false          # 方案名称，如"妈妈的和田手串"
      t.string :status, default: 'draft'   # draft / saved / ordered

      # 珠子配置：JSONB 数组，每项结构：
      # {
      #   "element_id":   1,          -- 关联 Element（珠子类型）
      #   "quantity":     18,         -- 颗数
      #   "position":     "main",     -- main(主珠) / spacer(间隔珠) / focal(核心珠)
      #   "size_override_mm": null,   -- 覆盖 element 默认尺寸（用户选了不同 size 时）
      #   "color_override": null      -- 覆盖颜色（运营允许的范围内）
      # }
      t.jsonb :bead_items, default: [], null: false

      # 绳子配置
      t.bigint :string_element_id            # 关联 Element（绳子类型）
      t.string :string_color_hex             # 绳子颜色（可覆盖元素默认色）
      t.string :string_color_name

      # 手串整体属性
      t.integer :total_beads                 # 总珠数（冗余，方便查询）
      t.decimal :estimated_length_mm,
                precision: 7, scale: 2       # 估算周长（毫米）
      t.string  :wrist_size                  # 手腕尺寸档位：S/M/L/XL 或 free_size
      t.string  :knot_style                  # 打结方式：single_knot / double_knot / adjustable

      # 价格快照：下单时锁定各珠子单价，避免后续价格变动影响历史记录
      # { "element_id_1": "12.00", "string_element_id": "5.00", "total": "221.00" }
      t.jsonb :price_snapshot, default: {}

      t.text :notes                          # 用户备注

      t.datetime :saved_at                   # 用户主动保存时间
      t.timestamps
    end

    add_index :bracelet_configs, :status
    add_index :bracelet_configs, :string_element_id
    add_index :bracelet_configs, :bead_items, using: :gin
    add_index :bracelet_configs, :created_at
  end
end
