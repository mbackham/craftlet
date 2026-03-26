# frozen_string_literal: true

class CreateAnnouncements < ActiveRecord::Migration[7.1]
  def change
    create_table :announcements do |t|
      t.jsonb    :title,             default: {}, null: false, comment: "多语言标题"
      t.jsonb    :content,           default: {}, null: false, comment: "多语言内容"
      t.string   :announcement_type, default: "info", null: false, comment: "info / warning / maintenance"
      t.string   :status,            default: "draft", null: false, comment: "draft / published / archived"
      t.boolean  :is_pinned,         default: false,  comment: "是否置顶"
      t.datetime :publish_at,                         comment: "定时发布时间"
      t.datetime :expire_at,                          comment: "过期时间"
      t.timestamps
    end

    add_index :announcements, :status
    add_index :announcements, :announcement_type
    add_index :announcements, :is_pinned
    add_index :announcements, :publish_at
  end
end
