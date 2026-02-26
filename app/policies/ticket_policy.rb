# frozen_string_literal: true

class TicketPolicy < ApplicationPolicy
  def index?
    user.admin_can?("ticket:read") || user.admin_can?("ticket:manage")
  end

  def show?
    index?
  end

  def create?
    user.admin_can?("ticket:manage")
  end

  def new?
    create?
  end

  def update?
    user.admin_can?("ticket:manage")
  end

  def destroy?
    false
  end

  # Custom actions
  def assign?
    user.admin_can?("ticket:manage")
  end

  def start_work?
    user.admin_can?("ticket:manage")
  end

  def resolve?
    user.admin_can?("ticket:manage")
  end

  def close_ticket?
    user.admin_can?("ticket:manage")
  end

  def reopen?
    user.admin_can?("ticket:manage")
  end

  def reply?
    user.admin_can?("ticket:manage")
  end

  def assign_merchant?
    user.admin_can?("ticket:manage")
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("ticket:read") || user.admin_can?("ticket:manage")
        scope.all
      else
        scope.none
      end
    end
  end
end
