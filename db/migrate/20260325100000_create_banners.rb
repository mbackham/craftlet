# frozen_string_literal: true

class CreateBanners < ActiveRecord::Migration[7.1]
  def change
    create_table :banners do |t|
      t.jsonb    :title,     default: {}, null: false, comment: "多语言标题 { zh-CN: ..., en: ... }"
      t.string   :link_url,                            comment: "点击跳转链接"
      t.string   :image_key,                           comment: "OSS 图片 Key"
      t.integer  :position,  default: 0,               comment: "排序位置"
      t.string   :placement, default: "home", null: false, comment: "展示位置: home / category / detail"
      t.string   :status,    default: "draft", null: false, comment: "draft / active / inactive"
      t.datetime :start_at,                            comment: "定时上线"
      t.datetime :end_at,                              comment: "定时下线"
      t.timestamps
    end

    add_index :banners, :status
    add_index :banners, :placement
    add_index :banners, :position
  end
end
