# frozen_string_literal: true

# MerchantProfileBlueprint — 商家资料序列化器
#
# Views:
#   :default — 状态摘要（用于首页/审核状态查询）
#   :detail  — 完整资料（含脱敏银行卡、地址等，供商家自己查看）
class MerchantProfileBlueprint < BaseBlueprint
  fields :status, :shop_name

  field :rejected_reason do |profile|
    profile.status == 'rejected' ? profile.reject_reason : nil
  end

  field :approved_at do |p|
    p.approved_at&.iso8601
  end

  field :rejected_at do |p|
    p.rejected_at&.iso8601
  end

  field :created_at do |p|
    p.created_at&.iso8601
  end

  field :updated_at do |p|
    p.updated_at&.iso8601
  end

  # ── 详情视图（供商家查看自己的完整资料）────────────────────────────────
  view :detail do
    fields :bank_name, :bank_branch,
           :address_province, :address_city, :address_district, :address_detail

    field :full_address do |p|
      p.full_address
    end

    # 脱敏字段
    field :masked_bank_account_no do |p|
      p.masked_bank_account_no
    end

    # 资质文件 key（前端用于生成 OSS 预签名 URL）
    field :license_file_key do |p|
      p.license_file_key
    end

    field :idcard_front_key do |p|
      p.idcard_front_key
    end

    field :idcard_back_key do |p|
      p.idcard_back_key
    end

    field :deposit_amount do |p|
      p.deposit_amount&.to_s
    end
  end
end
