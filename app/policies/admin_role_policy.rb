# frozen_string_literal: true

class AdminRolePolicy < ApplicationPolicy
  def index?
    true # All admin users can view roles
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def destroy?
    true
  end

  def manage_permissions?
    true
  end

  def export?
    true
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
