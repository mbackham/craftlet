# frozen_string_literal: true

class RiskRulePolicy < ApplicationPolicy
  def index?
    user.admin_can?("risk:read") || user.admin_can?("risk:manage")
  end

  def show?
    index?
  end

  def create?
    user.admin_can?("risk:manage")
  end

  def new?
    create?
  end

  def update?
    user.admin_can?("risk:manage")
  end

  def destroy?
    false
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("risk:read") || user.admin_can?("risk:manage")
        scope.all
      else
        scope.none
      end
    end
  end
end
