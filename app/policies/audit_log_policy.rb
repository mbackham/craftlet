# frozen_string_literal: true

class AuditLogPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    false # Audit logs are system-generated only
  end

  def update?
    false # Audit logs are immutable
  end

  def destroy?
    false # Audit logs should never be deleted via UI
  end

  def export?
    true
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
