# frozen_string_literal: true

module Api
  module V1
    class FaqsController < BaseController
      skip_before_action :authenticate_user!, only: [:index], raise: false

      def index
        locale = params[:locale] || I18n.locale.to_s

        categories = FaqCategory.active.ordered.includes(:faqs)

        render json: categories.map { |cat|
          {
            id: cat.id,
            name: cat.name[locale] || cat.name[I18n.default_locale.to_s] || cat.name.values.first,
            slug: cat.slug,
            faqs: cat.faqs.active.ordered.map { |faq|
              {
                id: faq.id,
                question: faq.question[locale] || faq.question[I18n.default_locale.to_s] || faq.question.values.first,
                answer: faq.answer[locale] || faq.answer[I18n.default_locale.to_s] || faq.answer.values.first
              }
            }
          }
        }
      end
    end
  end
end
