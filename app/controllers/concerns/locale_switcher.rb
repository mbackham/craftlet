module LocaleSwitcher
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private

  def set_locale
    locale = params[:locale].presence || session[:locale].presence || I18n.default_locale
    locale = locale.to_s
    locale = I18n.available_locales.map(&:to_s).include?(locale) ? locale : I18n.default_locale.to_s
    I18n.locale = locale.to_sym
    session[:locale] = locale
  end
end
