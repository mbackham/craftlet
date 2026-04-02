# frozen_string_literal: true

class DwDimUserPolicy < ApplicationPolicy
  def index?
    user.admin_can?('user:read')
  end

  def show?
    index?
  end

  class Scope < Scope
    def resolve
      user.admin_can?('user:read') ? scope.all : scope.none
    end
  end
end
