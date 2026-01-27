# frozen_string_literal: true

class AdminPermissionPolicy < ApplicationPolicy
  def index?
    true # All admin users can view permissions
  end

  def show?
    true
  end

  def create?
    false # Permissions are code-managed via seeds
  end

  def update?
    false # Permissions are code-managed via seeds
  end

  def destroy?
    false # Permissions are code-managed via seeds
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

