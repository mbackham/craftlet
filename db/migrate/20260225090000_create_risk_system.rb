# frozen_string_literal: true

class CreateRiskSystem < ActiveRecord::Migration[7.1]
  def change
    # -----------------------------------------------------------------------
    # risk_rules — 风控规则表
    # -----------------------------------------------------------------------
    create_table :risk_rules do |t|
      t.string  :code,        null: false  # 规则代码: high_freq_refund, high_amount_refund, merchant_bid_spam
      t.string  :name,        null: false  # 规则名称
      t.text    :description               # 规则描述
      t.string  :category,    default: "general"  # 分类: refund, order, merchant, general
      t.string  :severity,    default: "medium"   # 严重级: low, medium, high, critical
      t.jsonb   :params,      default: {}, null: false  # 规则参数 (阈值等)
      t.boolean :enabled,     default: true, null: false
      t.timestamps
    end

    add_index :risk_rules, :code, unique: true
    add_index :risk_rules, :enabled
    add_index :risk_rules, :category

    # -----------------------------------------------------------------------
    # risk_events — 风控事件表
    # -----------------------------------------------------------------------
    create_table :risk_events do |t|
      t.references :risk_rule, null: false, foreign_key: true
      t.string     :status,    default: "pending", null: false  # pending, ignored, processed
      t.uuid       :subject_id, null: false  # 触发主体 (User UUID)
      t.string     :subject_type, default: "User"
      t.string     :trigger_source             # 触发来源: refund_create, bid_create, etc.
      t.jsonb      :context,   default: {}, null: false  # 触发上下文数据
      t.text       :resolution_note            # 处理备注
      t.uuid       :resolved_by_id             # 处理人 (AdminUser UUID)
      t.datetime   :resolved_at

      t.timestamps
    end

    add_index :risk_events, :status
    add_index :risk_events, :subject_id
    add_index :risk_events, :trigger_source
    add_index :risk_events, [:risk_rule_id, :subject_id]
  end
end
