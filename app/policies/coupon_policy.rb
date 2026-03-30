# frozen_string_literal: true

class CouponPolicy < ApplicationPolicy
  def index?
    user.admin_can?("marketing:read") || user.admin_can?("marketing:manage")
  end

  def show?
    index?
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("marketing:read") || user.admin_can?("marketing:manage")
        scope.all
      else
        scope.none
      end
    end
  end
end
