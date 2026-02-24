# frozen_string_literal: true

class RefundPolicy < ApplicationPolicy
  # 能看到退款列表/详情：拥有 refund:read 或 refund:approve 权限
  def index?
    user.admin_can?("refund:read") || user.admin_can?("refund:approve")
  end

  def show?
    index?
  end

  # 审批退款：需要 refund:approve 权限（super admin 自动满足）
  def approve?
    user.admin_can?("refund:approve")
  end

  def reject?
    user.admin_can?("refund:approve")
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("refund:read") || user.admin_can?("refund:approve")
        scope.all
      else
        scope.none
      end
    end
  end
end
