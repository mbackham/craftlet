# frozen_string_literal: true

class ElementPolicy < ApplicationPolicy
  def index?
    user.admin_can?("element:read") || user.admin_can?("element:manage")
  end

  def show?
    index?
  end

  def create?
    user.admin_can?("element:manage")
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  def shelf?
    create?
  end

  def unshelf?
    create?
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("element:read") || user.admin_can?("element:manage")
        scope.all
      else
        scope.none
      end
    end
  end
end
