# frozen_string_literal: true

class CouponTemplatePolicy < ApplicationPolicy
  def index?
    user.admin_can?("marketing:read") || user.admin_can?("marketing:manage")
  end

  def show?
    index?
  end

  def create?
    user.admin_can?("marketing:manage")
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  def activate?
    create?
  end

  def deactivate?
    create?
  end

  def issue?
    create?
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
