# frozen_string_literal: true

class OrderPolicy < ApplicationPolicy
  def index?
    user.admin_can?("order:read")
  end

  def show?
    index?
  end

  def assign_merchant?
    user.admin_can?("order:read")
  end

  def create_refund_ticket?
    user.admin_can?("order:read")
  end

  # Read-only, no create/update/destroy

  class Scope < Scope
    def resolve
      if user.admin_can?("order:read")
        scope.all
      else
        scope.none
      end
    end
  end
end
