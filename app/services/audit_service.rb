# frozen_string_literal: true

# AuditService - Unified audit logging service
# Usage:
#   AuditService.log!(
#     action: 'create',
#     actor: current_user,
#     target: @user,
#     after: @user.attributes
#   )
class AuditService
  class << self
    # Main logging method
    # @param action [String] The action performed (create, update, destroy, etc.)
    # @param actor [User, nil] The user who performed the action
    # @param target [ActiveRecord::Base, nil] The object being acted upon
    # @param before [Hash, nil] State before the change
    # @param after [Hash, nil] State after the change
    # @param metadata [Hash] Additional metadata
    # @param request [ActionDispatch::Request, nil] The HTTP request object
    def log!(action:, actor: nil, target: nil, before: nil, after: nil, metadata: {}, request: nil)
      audit_data = build_audit_data(
        action: action,
        actor: actor,
        target: target,
        before: before,
        after: after,
        metadata: metadata,
        request: request
      )

      AuditLog.create!(audit_data)
    rescue StandardError => e
      # Log the error but don't fail the main operation
      Rails.logger.error("Failed to create audit log: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      nil
    end

    private

    def build_audit_data(action:, actor:, target:, before:, after:, metadata:, request:)
      data = {
        action: action,
        metadata: metadata
      }

      # Add actor information (polymorphic)
      if actor
        data[:actor_type] = actor.class.name
        # Convert ID to UUID string format (pad with zeros if needed)
        data[:actor_id] = format_as_uuid(actor.id)
      else
        # Use system as default actor
        data[:actor_type] = 'System'
        data[:actor_id] = '00000000-0000-0000-0000-000000000000' # UUID for system
      end

      # Add target information if provided
      if target
        data[:target_type] = target.class.name
        data[:target_id] = target.id
        # subject is an alias for target (legacy field)
        data[:subject_type] = target.class.name
        data[:subject_id] = target.id.is_a?(String) ? target.id : '00000000-0000-0000-0000-000000000000'
      else
        # Default values for required fields
        data[:subject_type] = 'Unknown'
        data[:subject_id] = '00000000-0000-0000-0000-000000000000'
      end

      # Add before/after states (filter sensitive data)
      data[:before] = sanitize_attributes(before) if before.present?
      data[:after] = sanitize_attributes(after) if after.present?

      # Extract request context if available
      if request
        data[:request_id] = request.request_id
        data[:ip] = request.remote_ip
        data[:user_agent] = request.user_agent
      end

      data
    end

    # Remove sensitive attributes from logged data
    def sanitize_attributes(attributes)
      return attributes unless attributes.is_a?(Hash)

      sensitive_keys = %w[
        password
        encrypted_password
        password_confirmation
        password_digest
        token
        secret
        api_key
        authentication_token
      ]

      attributes.except(*sensitive_keys)
    end

    # Convert integer ID to UUID string format
    def format_as_uuid(id)
      return id if id.is_a?(String) && id.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
      
      # For integer IDs, create a UUID-like string
      # Format: 00000000-0000-0000-0000-{12 digit number}
      sprintf('00000000-0000-0000-0000-%012d', id.to_i)
    end
  end
end
