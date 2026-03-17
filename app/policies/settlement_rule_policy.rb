# frozen_string_literal: true

class SettlementRulePolicy < ApplicationPolicy
  def index?
    user.admin_can?("settlement:read")
  end

  def show?
    index?
  end

  def create?
    user.admin_can?("settlement:manage")
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("settlement:read")
        scope.all
      else
        scope.none
      end
    end
  end
end
