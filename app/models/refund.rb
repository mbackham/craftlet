class Refund < ApplicationRecord
  belongs_to :order
  belongs_to :payment
end
