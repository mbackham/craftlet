# frozen_string_literal: true

module Api
  module V1
    # GET    /api/v1/bracelet_configs          — 当前用户的手串方案列表
    # GET    /api/v1/bracelet_configs/:id      — 方案详情（含珠子元素信息）
    # POST   /api/v1/bracelet_configs          — 创建新方案
    # PATCH  /api/v1/bracelet_configs/:id      — 更新方案
    # DELETE /api/v1/bracelet_configs/:id      — 删除草稿方案
    # POST   /api/v1/bracelet_configs/:id/save — 保存方案（draft → saved）
    class BraceletConfigsController < BaseController
      include Pagy::Method

      before_action :set_config, only: %i[show update destroy save]

      def index
        configs = current_user.bracelet_configs.order(updated_at: :desc)
        configs = configs.where(status: params[:status]) if params[:status].present?
        pagy, records = pagy(configs)
        render_paginated(data: BraceletConfigBlueprint.render_as_hash(records), pagy: pagy)
      end

      def show
        render_success(data: BraceletConfigBlueprint.render_as_hash(@config, view: :detail))
      end

      def create
        config = current_user.bracelet_configs.build(config_params)
        if config.save
          render_success(data: BraceletConfigBlueprint.render_as_hash(config), status: :created)
        else
          render_error(message: config.errors.full_messages.join(', '), code: 'validation_failed')
        end
      end

      def update
        if @config.ordered?
          return render_error(message: I18n.t('bracelet_configs.errors.cannot_edit_ordered'),
                              code: 'not_editable', status: :unprocessable_entity)
        end
        if @config.update(config_params)
          render_success(data: BraceletConfigBlueprint.render_as_hash(@config, view: :detail))
        else
          render_error(message: @config.errors.full_messages.join(', '), code: 'validation_failed')
        end
      end

      def destroy
        unless @config.draft?
          return render_error(message: I18n.t('bracelet_configs.errors.can_only_delete_draft'),
                              code: 'not_deletable', status: :unprocessable_entity)
        end
        @config.destroy!
        render_success
      end

      def save
        if @config.save!
          render_success(data: BraceletConfigBlueprint.render_as_hash(@config))
        else
          render_error(message: I18n.t('bracelet_configs.errors.cannot_save'),
                       code: 'save_failed', status: :unprocessable_entity)
        end
      end

      private

      def set_config
        @config = current_user.bracelet_configs.find(params[:id])
      end

      def config_params
        params.require(:bracelet_config).permit(
          :name, :string_element_id, :string_color_hex, :string_color_name,
          :estimated_length_mm, :wrist_size, :knot_style, :notes,
          bead_items: [
            :element_id, :quantity, :position,
            :size_override_mm, :color_override
          ]
        )
      end
    end
  end
end
