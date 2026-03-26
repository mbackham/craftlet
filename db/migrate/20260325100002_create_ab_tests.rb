# frozen_string_literal: true

class CreateAbTests < ActiveRecord::Migration[7.1]
  def change
    create_table :ab_tests do |t|
      t.string   :name,               null: false,    comment: "实验名称"
      t.string   :test_key,           null: false,    comment: "唯一标识 key"
      t.text     :description,                        comment: "实验描述"
      t.string   :status,             default: "draft", null: false, comment: "draft / running / paused / completed"
      t.jsonb    :variants,           default: [],    null: false, comment: '变体配置 [{ "name": "A", "weight": 50, "config": {} }]'
      t.integer  :traffic_percentage, default: 100,   comment: "总流量百分比"
      t.datetime :start_at,                           comment: "开始时间"
      t.datetime :end_at,                             comment: "结束时间"
      t.timestamps
    end

    add_index :ab_tests, :test_key, unique: true
    add_index :ab_tests, :status
  end
end
