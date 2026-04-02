# frozen_string_literal: true

class EtlCleanRulePolicy < ApplicationPolicy
  def index?
    user.admin_can?('etl:read')
  end

  def show?
    index?
  end

  def create?
    user.admin_can?('etl:manage')
  end

  def update?
    user.admin_can?('etl:manage')
  end

  def destroy?
    user.admin_can?('etl:manage')
  end

  class Scope < Scope
    def resolve
      user.admin_can?('etl:read') ? scope.all : scope.none
    end
  end
end
