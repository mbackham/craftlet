# frozen_string_literal: true

class InvoicePolicy < ApplicationPolicy
  def index?
    user.admin_can?("settlement:read")
  end

  def show?
    index?
  end

  def create?
    user.admin_can?("settlement:manage")
  end

  def issue?
    create?
  end

  def ship?
    create?
  end

  def receive?
    create?
  end

  def reject_invoice?
    create?
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
