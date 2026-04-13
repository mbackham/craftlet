# frozen_string_literal: true

# app/blueprints/user_blueprint.rb
#
# UserBlueprint — User 模型的 JSON 序列化器
# UserBlueprint — JSON serializer for the User model
#
# 视图 / Views:
#   :default — 基础字段（公开安全，无敏感信息）
#   :me      — 当前登录用户的完整信息（含 locale、phone 等）
#
# 用法 / Usage:
#   UserBlueprint.render(user)               # JSON string, default view
#   UserBlueprint.render(user, view: :me)    # JSON string, :me view
#   UserBlueprint.render_as_hash(user)       # Hash, default view
#
class UserBlueprint < BaseBlueprint
  # -----------------------------------------------------------------------
  # Default view — 基础公开字段 / Basic public fields
  # -----------------------------------------------------------------------
  fields :id, :nickname, :auth_provider, :created_at

  field :created_at do |user|
    user.created_at&.iso8601
  end

  # -----------------------------------------------------------------------
  # :me view — 当前用户完整信息 / Full info for the current user
  # -----------------------------------------------------------------------
  view :me do
    fields :email, :phone, :locale, :status

    field :email do |user|
      # 空字符串（手机号用户占位符）返回 nil / Empty string (phone-only placeholder) → nil
      user.email.presence
    end
  end
end
