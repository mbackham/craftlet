class AdminUserPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    admin?
  end

  def new?
    create?
  end

  def update?
    admin?
  end

  def edit?
    update?
  end

  def destroy?
    admin?
  end

  def read?
    index?
  end

  class Scope < Scope
    def resolve
      admin? ? scope.all : scope.none
    end

    private

    def admin?
      user&.admin?
    end
  end

  private

  def admin?
    user&.admin?
  end
end
