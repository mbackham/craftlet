# frozen_string_literal: true

class BankStatementPolicy < ApplicationPolicy
  def index?
    user.admin_can?("payment:read")
  end

  def show?
    index?
  end

  def create?
    user.admin_can?("payment:manage") || user.admin_can?("payment:read")
  end

  def new?
    create?
  end

  def process_batch?
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
