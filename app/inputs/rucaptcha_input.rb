class RucaptchaInput
  include Formtastic::Inputs::Base

  def to_html
    input_wrapping do
      html = +""
      html << label_html
      html << '<div class="rucaptcha-wrap">'
      html << template.rucaptcha_input_tag(input_html_options)
      html << template.rucaptcha_image_tag(alt: template.t("rucaptcha.refresh"),
                                           title: template.t("rucaptcha.refresh"))
      html << "</div>"
      html.html_safe
    end
  end

  def input_html_options
    super.merge(id: "_rucaptcha", class: "rucaptcha-input")
  end
end
