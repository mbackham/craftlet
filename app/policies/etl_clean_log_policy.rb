# frozen_string_literal: true

class EtlCleanLogPolicy < ApplicationPolicy
  def index?
    user.admin_can?('etl:read')
  end

  def show?
    index?
  end

  class Scope < Scope
    def resolve
      user.admin_can?('etl:read') ? scope.all : scope.none
    end
  end
end
