module ActiveAdmin
  class CommentPolicy < ApplicationPolicy
    def index?
      admin?
    end

    def show?
      admin?
    end

    def create?
      admin?
    end

    def update?
      admin?
    end

    def destroy?
      admin?
    end

    def read?
      index?
    end

    private

    def admin?
      user&.admin?
    end
  end
end
