# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/elements        — 公开只读，支持多维度过滤
    # GET /api/v1/elements/:id    — 公开只读
    class ElementsController < BaseController
      include Pagy::Method

      skip_before_action :authenticate_from_logto!

      ALLOWED_SORTS = %w[price size_mm created_at shelved_at name].freeze

      def index
        scope = Element.on_shelf
        scope = apply_filters(scope)
        scope = apply_sort(scope)

        pagy, elements = pagy(scope, limit: params.fetch(:per_page, 20).to_i.clamp(1, 100))
        render_paginated(data: ElementBlueprint.render_as_hash(elements), pagy: pagy)
      end

      def show
        element = Element.on_shelf.find(params[:id])
        render_success(data: ElementBlueprint.render_as_hash(element))
      end

      private

      def apply_filters(scope)
        scope = scope.where(element_type: params[:element_type])   if params[:element_type].present?
        scope = scope.where(material_type: params[:material_type]) if params[:material_type].present?
        scope = scope.where(color_hex: params[:color_hex])         if params[:color_hex].present?
        scope = scope.where("size_mm >= ?", params[:size_min])     if params[:size_min].present?
        scope = scope.where("size_mm <= ?", params[:size_max])     if params[:size_max].present?
        scope = scope.where("price <= ?", params[:price_max])      if params[:price_max].present?
        scope = scope.where(origin_region: params[:origin_region]) if params[:origin_region].present?
        scope = scope.where("tags @> ?", [params[:tag]].to_json)   if params[:tag].present?
        if params.key?(:is_natural)
          scope = scope.where(is_natural: ActiveModel::Type::Boolean.new.cast(params[:is_natural]))
        end
        scope
      end

      def apply_sort(scope)
        col = ALLOWED_SORTS.include?(params[:sort]) ? params[:sort] : 'created_at'
        dir = params[:direction] == 'asc' ? 'asc' : 'desc'
        scope.order("#{col} #{dir}")
      end
    end
  end
end
