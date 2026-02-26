# frozen_string_literal: true

class RiskEventPolicy < ApplicationPolicy
  def index?
    user.admin_can?("risk:read") || user.admin_can?("risk:manage")
  end

  def show?
    index?
  end

  def ignore?
    user.admin_can?("risk:manage")
  end

  def process_event?
    user.admin_can?("risk:manage")
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("risk:read") || user.admin_can?("risk:manage")
        scope.all
      else
        scope.none
      end
    end
  end
end
