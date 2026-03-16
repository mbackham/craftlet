# frozen_string_literal: true

class ReconciliationBatchPolicy < ApplicationPolicy
  def index?
    user.admin_can?("payment:read")
  end

  def show?
    index?
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
