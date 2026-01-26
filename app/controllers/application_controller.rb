class ApplicationController < ActionController::Base
  include LocaleSwitcher

  def pundit_user
    current_admin_user || current_user
  end
end
