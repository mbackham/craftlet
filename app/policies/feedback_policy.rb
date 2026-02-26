# frozen_string_literal: true

class FeedbackPolicy < ApplicationPolicy
  def index?
    user.admin_can?("feedback:read") || user.admin_can?("feedback:manage")
  end

  def show?
    index?
  end

  def create?
    false # Feedbacks are created via API, not ActiveAdmin
  end

  def update?
    user.admin_can?("feedback:manage")
  end

  def destroy?
    false # Feedbacks should be soft-deleted or archived, not destroyed
  end

  class Scope < Scope
    def resolve
      if user.admin_can?("feedback:read") || user.admin_can?("feedback:manage")
        scope.all
      else
        scope.none
      end
    end
  end
end
