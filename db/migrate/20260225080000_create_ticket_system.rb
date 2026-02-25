# frozen_string_literal: true

class CreateTicketSystem < ActiveRecord::Migration[7.1]
  def change
    # -----------------------------------------------------------------------
    # tickets — 工单主表
    # -----------------------------------------------------------------------
    create_table :tickets do |t|
      t.string   :ticket_no,     null: false                # 工单编号
      t.string   :subject,       null: false                # 主题
      t.text     :description                               # 描述
      t.string   :category,      default: "general"         # 分类: general, payment, order, merchant, other
      t.string   :priority,      default: "normal"          # 优先级: low, normal, high, urgent
      t.string   :status,        default: "open", null: false # AASM: open, assigned, in_progress, resolved, closed
      t.uuid     :creator_id,    null: false                # 创建人 (User UUID or AdminUser UUID)
      t.string   :creator_type,  default: "User"            # polymorphic: User / AdminUser
      t.uuid     :assignee_id                               # 处理人 (AdminUser UUID)
      t.uuid     :order_id                                  # 关联订单 (optional)
      t.datetime :assigned_at
      t.datetime :resolved_at
      t.datetime :closed_at

      t.timestamps
    end

    add_index :tickets, :ticket_no,   unique: true
    add_index :tickets, :status
    add_index :tickets, :priority
    add_index :tickets, :creator_id
    add_index :tickets, :assignee_id
    add_index :tickets, :order_id
    add_index :tickets, :category

    # -----------------------------------------------------------------------
    # ticket_messages — 工单消息/回复
    # -----------------------------------------------------------------------
    create_table :ticket_messages do |t|
      t.references :ticket,       null: false, foreign_key: true
      t.uuid       :sender_id,    null: false       # 发送人 UUID
      t.string     :sender_type,  default: "User"   # polymorphic: User / AdminUser
      t.text       :content,      null: false        # 消息内容
      t.boolean    :internal,     default: false     # 内部备注（仅运营可见）

      t.timestamps
    end

    add_index :ticket_messages, :sender_id

    # -----------------------------------------------------------------------
    # ticket_attachments — 工单附件
    # -----------------------------------------------------------------------
    create_table :ticket_attachments do |t|
      t.references :ticket_message, null: false, foreign_key: true
      t.string     :file_name,      null: false    # 文件名
      t.string     :file_type                      # MIME type
      t.integer    :file_size                      # 文件大小 bytes
      t.string     :oss_key                        # OSS 存储 key
      t.string     :url                            # 直接链接 (先挂链接)

      t.timestamps
    end
  end
end
