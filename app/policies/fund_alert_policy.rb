# frozen_string_literal: true

class FundAlertPolicy < ApplicationPolicy
  def index?
    user.admin_can?("finance:manage") || user.admin_can?("finance:read")
  end

  def show?
    index?
  end

  def acknowledge?
    user.admin_can?("finance:manage")
  end

  def ignore?
    user.admin_can?("finance:manage")
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("finance:manage") || user.admin_can?("finance:read")
        scope.all
      else
        scope.none
      end
    end
  end
end
