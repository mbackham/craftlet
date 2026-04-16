# frozen_string_literal: true

# app/blueprints/bid_blueprint.rb
class BidBlueprint < BaseBlueprint
  field :amount do |bid|
    bid.amount.to_s
  end

  fields :status

  field :bidder_nickname do |bid|
    bid.bidder&.nickname
  end

  field :created_at do |bid|
    bid.created_at&.iso8601
  end
end
