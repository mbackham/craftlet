module ActiveAdmin
  class PagePolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def show?
      user.present?
    end

    def read?
      show?
    end
  end
end
