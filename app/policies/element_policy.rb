# frozen_string_literal: true

class ElementPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.respond_to?(:admin_can?) && user.admin_can?('element:manage')
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
      scope.all
    end
  end
end
