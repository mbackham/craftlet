# frozen_string_literal: true

module Orders
  # Assigns a merchant to an order on behalf of the customer.
  #
  # Business rules:
  #   - Order must be in "paid" status (awaiting merchant assignment)
  #   - Merchant user must be active and their MerchantProfile approved
  #   - Merchant cannot be the order's customer
  #   - Creates an "accepted" Bid for the assigned merchant
  #   - Rejects all other pending Bids on the order
  #   - Transitions order to "accepted" via AASM
  #   - Writes AuditLog for full traceability
  #
  # Usage:
  #   result = Orders::AssignMerchantService.new(
  #     order:         order,
  #     merchant_user: merchant,
  #     admin_user:    current_admin_user,
  #     request:       request
  #   ).call
  #
  #   result.success? # => true / false
  #   result.error     # => error string or nil
  class AssignMerchantService
    attr_reader :error

    def initialize(order:, merchant_user:, admin_user:, request: nil)
      @order         = order
      @merchant_user = merchant_user
      @admin_user    = admin_user
      @request       = request
      @error         = nil
    end

    def call
      validate!

      ActiveRecord::Base.transaction do
        @order.lock! # pessimistic lock — prevent concurrent assignment

        # Re-validate inside lock
        unless @order.status == "paid"
          raise InvalidStateError, "订单状态不允许指派商家（当前: #{@order.status}）"
        end

        merchant_uuid = format_user_id_as_uuid(@merchant_user.id)
        old_merchant_id = @order.merchant_id

        # Update order merchant
        @order.update!(merchant_id: merchant_uuid)

        # Create accepted Bid for the assigned merchant
        Bid.create!(
          order:     @order,
          bidder_id: merchant_uuid,
          amount:    @order.total_amount,
          status:    "accepted"
        )

        # Reject all other pending Bids
        @order.bids.pending.where.not(bidder_id: merchant_uuid).find_each do |bid|
          bid.update!(status: "rejected")
        end

        # Transition order state: paid → accepted
        @order.accept!

        # AuditLog
        AuditService.log!(
          action:   "assign_merchant",
          actor:    @admin_user,
          target:   @order,
          before:   { merchant_id: old_merchant_id, status: "paid" },
          after:    { merchant_id: merchant_uuid, status: "accepted" },
          metadata: {
            action_type:     "order_assign_merchant",
            merchant_email:  @merchant_user.email,
            merchant_user_id: @merchant_user.id
          },
          request: @request
        )
      end

      self
    rescue InvalidStateError, ArgumentError => e
      @error = e.message
      self
    rescue ActiveRecord::RecordInvalid => e
      @error = e.message
      self
    rescue AASM::InvalidTransition => e
      @error = "订单状态转换失败: #{e.message}"
      self
    end

    def success?
      @error.nil?
    end

    private

    class InvalidStateError < StandardError; end

    def validate!
      # Order state check
      unless @order.status == "paid"
        raise InvalidStateError, "订单状态不允许指派商家（当前: #{@order.status}）"
      end

      # Merchant user active check
      unless @merchant_user.status == "active"
        raise InvalidStateError, "商家用户已被冻结，无法指派"
      end

      # MerchantProfile approved check
      profile = @merchant_user.merchant_profile
      unless profile&.approved?
        raise InvalidStateError, "商家资质未审核通过，无法指派"
      end

      # Self-assignment check
      merchant_uuid = format_user_id_as_uuid(@merchant_user.id)
      if @order.customer_id == merchant_uuid
        raise InvalidStateError, "不能将订单指派给下单用户自己"
      end
    end

    def format_user_id_as_uuid(id)
      # 委托给 UuidIdentity（统一转换逻辑，消除重复实现）
      # Delegates to UuidIdentity (single source of truth for UUID encoding)
      Order.id_to_uuid(id)
    end
  end
end
