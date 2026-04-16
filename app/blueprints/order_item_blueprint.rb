# frozen_string_literal: true

# app/blueprints/order_item_blueprint.rb
class OrderItemBlueprint < BaseBlueprint
  fields :item_type, :item_id, :name, :quantity

  field :unit_price do |item|
    item.unit_price.to_s
  end

  field :subtotal do |item|
    item.subtotal.to_s
  end
end
