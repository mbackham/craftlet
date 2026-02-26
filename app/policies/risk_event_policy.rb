# frozen_string_literal: true

class RiskEventPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def ignore?
    true
  end

  def process_event?
    true
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
