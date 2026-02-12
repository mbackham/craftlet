class CreateFeedbacks < ActiveRecord::Migration[7.1]
  def change
    create_table :feedbacks do |t|
      # 基本信息
      t.string :tracking_number, null: false, comment: '追踪号'
      t.string :feedback_type, null: false, default: 'other', comment: '反馈类型'
      t.string :subject, null: false, comment: '标题'
      t.text :content, null: false, comment: '内容'
      t.string :status, null: false, default: 'pending', comment: '状态'
      t.string :priority, default: 'medium', comment: '优先级'
      
      # 提交者信息
      t.bigint :user_id, comment: '用户ID'
      t.string :user_type, comment: '用户类型'
      t.string :submitter_name, comment: '提交者姓名'
      t.string :submitter_email, null: false, comment: '提交者邮箱'
      t.string :submitter_phone, comment: '提交者电话'
      
      # 环境信息
      t.string :page_url, comment: '页面URL'
      t.text :user_agent, comment: '浏览器信息'
      t.inet :ip_address, comment: 'IP地址'
      
      # 处理信息
      t.bigint :admin_user_id, comment: '处理人ID'
      t.text :admin_note, comment: '内部备注'
      t.datetime :resolved_at, comment: '解决时间'
      t.text :response, comment: '回复内容'

      t.timestamps
    end
    
    # 索引
    add_index :feedbacks, :tracking_number, unique: true
    add_index :feedbacks, :status
    add_index :feedbacks, :feedback_type
    add_index :feedbacks, :user_id
    add_index :feedbacks, :submitter_email
    add_index :feedbacks, :created_at
    add_index :feedbacks, :admin_user_id
    
    # 外键约束
    add_foreign_key :feedbacks, :users, column: :user_id, on_delete: :nullify
    add_foreign_key :feedbacks, :admin_users, column: :admin_user_id, on_delete: :nullify
  end
end
