# frozen_string_literal: true

class SettlementPolicy < ApplicationPolicy
  def index?
    user.admin_can?("settlement:read")
  end

  def show?
    index?
  end

  def approve?
    user.admin_can?("settlement:approve")
  end

  def reject?
    approve?
  end

  def payout?
    user.admin_can?("settlement:payout")
  end

  def confirm_arrival?
    payout?
  end

  def freeze_settlement?
    user.admin_can?("settlement:manage")
  end

  def retry_settlement?
    freeze_settlement?
  end

  def generate?
    user.admin_can?("settlement:manage")
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
