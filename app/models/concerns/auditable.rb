# frozen_string_literal: true

# Auditable concern for ActiveAdmin resources
# Automatically logs create, update, and destroy actions
#
# Usage in ActiveAdmin resource:
#   ActiveAdmin.register User do
#     include Auditable
#     # ... rest of your config
#   end
module Auditable
  extend ActiveSupport::Concern

  included do
    # Hook into ActiveAdmin's lifecycle callbacks
    controller do
      after_action :audit_create, only: [:create]
      after_action :audit_update, only: [:update]
      after_action :audit_destroy, only: [:destroy]

      private

      def audit_create
        return unless resource.persisted? && resource.errors.empty?

        AuditService.log!(
          action: 'create',
          actor: current_admin_user,
          target: resource,
          after: resource.attributes,
          request: request
        )
      end

      def audit_update
        return unless resource.persisted? && resource.errors.empty?
        return unless resource.previous_changes.present?

        before_attrs = resource.previous_changes.transform_values(&:first)
        after_attrs = resource.previous_changes.transform_values(&:last)

        AuditService.log!(
          action: 'update',
          actor: current_admin_user,
          target: resource,
          before: before_attrs,
          after: after_attrs,
          request: request
        )
      end

      def audit_destroy
        # For destroy, we need to capture the attributes before deletion
        destroyed_attrs = resource.attributes.dup

        AuditService.log!(
          action: 'destroy',
          actor: current_admin_user,
          target: resource,
          before: destroyed_attrs,
          request: request
        )
      end

      # Helper to log custom actions
      def log_custom_action(action_name, target: nil, before: nil, after: nil, metadata: {})
        AuditService.log!(
          action: action_name,
          actor: current_admin_user,
          target: target || resource,
          before: before,
          after: after,
          metadata: metadata,
          request: request
        )
      end
    end
  end
end
