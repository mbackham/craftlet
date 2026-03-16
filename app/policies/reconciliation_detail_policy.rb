# frozen_string_literal: true

class ReconciliationDetailPolicy < ApplicationPolicy
  def index?
    user.admin_can?("payment:read")
  end

  def show?
    index?
  end

  def claim?
    user.admin_can?("payment:manage") || user.admin_can?("payment:read")
  end

  def adjust?
    user.admin_can?("payment:manage") || user.admin_can?("payment:read")
  end

  def do_adjust?
    adjust?
  end

  def ignore?
    user.admin_can?("payment:manage") || user.admin_can?("payment:read")
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("payment:read")
        scope.all
      else
        scope.none
      end
    end
  end
end
