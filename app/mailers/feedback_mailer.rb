# frozen_string_literal: true

class FeedbackMailer < ApplicationMailer
  default from: 'support@craftlet.com'
  
  # 提交确认邮件
  def submission_confirmation(feedback)
    @feedback = feedback
    
    mail(
      to: feedback.submitter_email,
      subject: "【Craftlet】感谢您的反馈 - #{feedback.tracking_number}"
    )
  end
  
  # 处理完成通知邮件
  def response_notification(feedback)
    @feedback = feedback
    
    mail(
      to: feedback.submitter_email,
      subject: "【Craftlet】您的反馈已处理 - #{feedback.tracking_number}"
    )
  end
end
