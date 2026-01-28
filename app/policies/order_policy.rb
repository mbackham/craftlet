# frozen_string_literal: true

class OrderPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  # Read-only, no create/update/destroy

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
