# frozen_string_literal: true

class MerchantProfilePolicy < ApplicationPolicy
  def index?
    user.admin_can?('merchant:read') || user.admin_can?('merchant:approve')
  end

  def show?
    index?
  end

  def create?
    user.admin_can?('merchant:approve')
  end

  def update?
    user.admin_can?('merchant:approve')
  end

  def destroy?
    false # 商家资料不允许删除
  end

  def approve?
    user.admin_can?('merchant:approve')
  end

  def reject?
    user.admin_can?('merchant:approve')
  end

  def suspend?
    user.admin_can?('merchant:approve')
  end

  def unsuspend?
    user.admin_can?('merchant:approve')
  end

  class Scope < Scope
    def resolve
      if user.admin_can?('merchant:read') || user.admin_can?('merchant:approve')
        scope.all
      else
        scope.none
      end
    end
  end
end
