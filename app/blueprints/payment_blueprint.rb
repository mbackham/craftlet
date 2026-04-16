# frozen_string_literal: true

# app/blueprints/payment_blueprint.rb
class PaymentBlueprint < BaseBlueprint
  fields :channel, :status, :currency

  field :amount do |payment|
    payment.amount.to_s
  end

  field :paid_at do |payment|
    payment.paid_at&.iso8601
  end

  field :created_at do |payment|
    payment.created_at&.iso8601
  end
end
