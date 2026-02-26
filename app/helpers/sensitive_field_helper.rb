# frozen_string_literal: true

module SensitiveFieldHelper
  # 手机号脱敏：138****1234
  def mask_phone(phone)
    return nil if phone.blank?
    return phone if phone.length < 7
    phone[0..2] + "****" + phone[-4..]
  end

  # 银行卡号脱敏：**** **** **** 1234
  def mask_bank_account(account_no)
    return nil if account_no.blank?
    return account_no if account_no.length < 4
    "**** **** **** " + account_no[-4..]
  end

  # 判断当前用户可否查看明文
  def can_view_sensitive?(admin_user)
    return false if admin_user.nil?
    admin_user.admin? || admin_user.admin_can?("sensitive:view_plaintext")
  end

  # 展示脱敏字段：默认脱敏，有权限时显示原文
  def sensitive_field(value, mask_method:, admin_user:)
    return nil if value.blank?
    if can_view_sensitive?(admin_user)
      value
    else
      send(mask_method, value)
    end
  end
end
