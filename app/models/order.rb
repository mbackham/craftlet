class Order < ApplicationRecord
  include AASM

  belongs_to :customer, class_name: "User"
  belongs_to :merchant, class_name: "User", optional: true
  has_many :payments, dependent: :destroy
  has_many :refunds, dependent: :destroy

  aasm column: "status" do
    state :created, initial: true
    state :paid, :accepted, :producing, :delivered, :completed, :canceled, :refunded

    event :mark_paid do
      transitions from: :created, to: :paid
    end

    event :accept do
      transitions from: :paid, to: :accepted
    end

    event :start_producing do
      transitions from: :accepted, to: :producing
    end

    event :deliver do
      transitions from: :producing, to: :delivered
    end

    event :complete do
      transitions from: :delivered, to: :completed
    end

    event :cancel do
      transitions from: [:created, :paid, :accepted], to: :canceled
    end

    event :refund do
      transitions from: [:paid, :accepted, :producing, :delivered], to: :refunded
    end
  end
end
