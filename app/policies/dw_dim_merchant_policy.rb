# frozen_string_literal: true

class DwDimMerchantPolicy < ApplicationPolicy
  def index?
    user.admin_can?('merchant:read') || user.admin_can?('merchant:approve')
  end

  def show?
    index?
  end

  def rebuild_profile?
    user.admin_can?('merchant:approve')
  end

  def rebuild_all?
    user.admin_can?('merchant:approve')
  end

  class Scope < Scope
    def resolve
      if user.admin_can?('merchant:read') || user.admin_can?('merchant:approve')
        scope.all
      else
        scope.none
      end
    end
  end
end
