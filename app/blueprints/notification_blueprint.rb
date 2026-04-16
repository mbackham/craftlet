# frozen_string_literal: true

# app/blueprints/notification_blueprint.rb
class NotificationBlueprint < BaseBlueprint
  fields :title, :body, :notification_type, :data

  field :read do |notification|
    notification.read?
  end

  field :read_at do |notification|
    notification.read_at&.iso8601
  end

  field :created_at do |notification|
    notification.created_at&.iso8601
  end
end
