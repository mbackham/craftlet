# frozen_string_literal: true

class SettlementExceptionPolicy < ApplicationPolicy
  def index?
    user.admin_can?("settlement:read")
  end

  def show?
    index?
  end

  def resolve?
    user.admin_can?("settlement:manage")
  end

  def ignore?
    resolve?
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("settlement:read")
        scope.all
      else
        scope.none
      end
    end
  end
end
