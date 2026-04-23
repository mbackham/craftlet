# frozen_string_literal: true

class BraceletConfigPolicy < ApplicationPolicy
  def index?
    user.admin_can?("element:read") || user.admin_can?("element:manage")
  end

  def show?
    index?
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("element:read") || user.admin_can?("element:manage")
        scope.all
      else
        scope.none
      end
    end
  end
end
