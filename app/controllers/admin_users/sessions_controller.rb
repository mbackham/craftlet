module AdminUsers
  class SessionsController < ActiveAdmin::Devise::SessionsController
    include LocaleSwitcher

    prepend_before_action :validate_rucaptcha, only: :create

    private

    def validate_rucaptcha
      self.resource = resource_class.new(sign_in_params)
      return if verify_rucaptcha?

      flash.now[:alert] = I18n.t("rucaptcha.invalid")
      render :new, status: :unprocessable_entity
    end
  end
end
