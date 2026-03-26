# frozen_string_literal: true

class FaqCategoryPolicy < ApplicationPolicy
  def index?
    user.admin_can?("content:read") || user.admin_can?("content:manage")
  end

  def show?
    index?
  end

  def create?
    user.admin_can?("content:manage")
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("content:read") || user.admin_can?("content:manage")
        scope.all
      else
        scope.none
      end
    end
  end
end
