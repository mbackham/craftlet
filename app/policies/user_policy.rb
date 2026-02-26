# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    user.admin_can?("user:read") || user.admin_can?("user:manage")
  end

  def show?
    index?
  end

  def create?
    user.admin_can?("user:manage")
  end

  def update?
    user.admin_can?("user:manage")
  end

  def destroy?
    user.admin_can?("user:manage")
  end

  def activate?
    user.admin_can?("user:manage")
  end

  def deactivate?
    user.admin_can?("user:manage")
  end

  def export?
    user.admin_can?("user:read") || user.admin_can?("user:manage")
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("user:read") || user.admin_can?("user:manage")
        scope.all
      else
        scope.none
      end
    end
  end
end
