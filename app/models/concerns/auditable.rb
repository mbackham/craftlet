# frozen_string_literal: true

# Auditable concern for ActiveAdmin controllers
# Provides audit logging methods
module Auditable
  extend ActiveSupport::Concern

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
end
