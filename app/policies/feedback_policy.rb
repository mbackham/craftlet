# frozen_string_literal: true

class FeedbackPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    false # Feedbacks are created via API, not ActiveAdmin
  end

  def update?
    true # Admins can update status, priority, admin_note, response
  end

  def destroy?
    false # Feedbacks should be soft-deleted or archived, not destroyed
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
