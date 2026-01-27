# frozen_string_literal: true

module AuditHelper
  # Format JSON data for display
  def format_audit_json(json_data)
    return content_tag(:span, '无', class: 'empty') if json_data.blank?

    content_tag(:pre, JSON.pretty_generate(json_data), class: 'audit-json')
  end

  # Display differences between before and after states
  def audit_diff(before, after)
    return content_tag(:span, '无变更', class: 'no-changes') if before.blank? && after.blank?

    before_hash = before || {}
    after_hash = after || {}

    changed_keys = (before_hash.keys + after_hash.keys).uniq.select do |key|
      before_hash[key] != after_hash[key]
    end

    if changed_keys.empty?
      return content_tag(:span, '无变更', class: 'no-changes')
    end

    content_tag(:table, class: 'audit-diff-table') do
      content_tag(:thead) do
        content_tag(:tr) do
          content_tag(:th, '字段') +
          content_tag(:th, '变更前') +
          content_tag(:th, '变更后')
        end
      end +
      content_tag(:tbody) do
        changed_keys.map do |key|
          content_tag(:tr) do
            content_tag(:td, key, class: 'field-name') +
            content_tag(:td, format_value(before_hash[key]), class: 'before-value') +
            content_tag(:td, format_value(after_hash[key]), class: 'after-value')
          end
        end.join.html_safe
      end
    end
  end

  # Format action with colored badge
  def action_badge(action)
    color = case action.to_s.downcase
            when 'create' then :ok
            when 'update' then :yes
            when 'destroy', 'delete' then :error
            when 'assign', 'grant' then :warning
            when 'revoke', 'remove' then :warning
            else nil
            end

    status_tag(action, color)
  end

  # Format target link
  def audit_target_link(audit_log)
    return '系统' if audit_log.target_type.blank?

    target_name = "#{audit_log.target_type}##{audit_log.target_id}"
    
    # Try to link to admin resource if it exists
    begin
      target_class = audit_log.target_type.constantize
      if target_class.respond_to?(:find) && (target = target_class.find_by(id: audit_log.target_id))
        # Check if ActiveAdmin resource exists
        resource_name = target_class.name.underscore.pluralize
        link_to target_name, "/admin/#{resource_name}/#{audit_log.target_id}"
      else
        content_tag(:span, target_name, class: 'deleted-target')
      end
    rescue NameError, ActiveRecord::RecordNotFound
      content_tag(:span, target_name)
    end
  end

  private

  def format_value(value)
    case value
    when nil
      content_tag(:span, 'nil', class: 'nil-value')
    when true, false
      content_tag(:span, value.to_s, class: 'boolean-value')
    when Hash, Array
      content_tag(:code, value.to_json, class: 'json-value')
    else
      truncate(value.to_s, length: 100)
    end
  end
end
