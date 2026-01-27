# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    true
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

  def activate?
    true
  end

  def deactivate?
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
