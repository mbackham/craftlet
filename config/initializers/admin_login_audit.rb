# frozen_string_literal: true

# Admin Login Audit — Records admin sign-in and sign-out events to AuditLog.
#
# Uses Warden callbacks so the tracking works regardless of how authentication
# happens (form login, remember-me cookie, session restore, etc.).
#
# Each event includes IP, user-agent, and a "login" / "logout" action string.

ActiveSupport::Reloader.to_prepare do
  Warden::Manager.after_authentication do |user, auth, opts|
    next unless user.is_a?(AdminUser)

    request = auth.request

    AuditService.log!(
      action:   "admin_login",
      actor:    user,
      target:   user,
      metadata: {
        action_type: "session",
        sign_in_count: user.sign_in_count,
        ip: request.remote_ip
      },
      request: request
    )

    Rails.logger.info(
      "[AdminAudit] admin##{user.id} (#{user.email}) signed in from #{request.remote_ip}"
    )
  end

  Warden::Manager.before_logout do |user, auth, opts|
    next unless user.is_a?(AdminUser)

    request = auth.request

    AuditService.log!(
      action:   "admin_logout",
      actor:    user,
      target:   user,
      metadata: { action_type: "session" },
      request: request
    )

    Rails.logger.info("[AdminAudit] admin##{user.id} (#{user.email}) signed out")
  end
end
