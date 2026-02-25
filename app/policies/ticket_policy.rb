# frozen_string_literal: true

class TicketPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def new?
    create?
  end

  def update?
    true
  end

  def destroy?
    false
  end

  # Custom actions
  def assign?
    true
  end

  def start_work?
    true
  end

  def resolve?
    true
  end

  def close_ticket?
    true
  end

  def reopen?
    true
  end

  def reply?
    true
  end

  def assign_merchant?
    true
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
