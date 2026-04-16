# frozen_string_literal: true

require 'swagger_helper'

# spec/requests/api/v1/content_swagger_spec.rb
#
# 内容运营模块 Swagger 文档
# 所有接口公开，无需 JWT 认证
#
# GET /api/v1/banners        — Banner 列表
# GET /api/v1/announcements  — 公告列表
# GET /api/v1/faqs           — FAQ 分类列表
#
RSpec.describe 'Content API (公开)', type: :request do
  # ── Banners ──────────────────────────────────────────────────────────────

  path '/api/v1/banners' do
    get 'Banner 列表' do
      tags '内容运营'
      description <<~DESC
        获取当前有效的首页 Banner 列表，按 `position` 升序排列。
        - **无需认证**，App 首页直接调用
        - 支持 `?placement=` 按位置过滤（如 `home_top`、`home_middle`）
        - 支持 `?locale=` 指定语言（默认 `zh-CN`），多语言 title 自动降级
      DESC
      produces 'application/json'

      parameter name: :placement,
                in: :query,
                type: :string,
                required: false,
                description: 'Banner 位置筛选，如 home_top / home_middle / splash'

      parameter name: :locale,
                in: :query,
                type: :string,
                required: false,
                description: '语言代码，如 zh-CN / en，默认 zh-CN'

      response '200', '获取成功' do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id:        { type: :integer, example: 1 },
                   title:     { type: :string,  example: '春节特惠活动' },
                   image_key: { type: :string,  example: 'banners/spring_2026.jpg', description: 'OSS 对象 Key，前端拼接 CDN 域名使用' },
                   link_url:  { type: :string,  example: 'https://craftlet.com/promo/spring', description: '点击跳转 URL，可为空' },
                   position:  { type: :integer, example: 1, description: '排列顺序，数字越小越靠前' },
                   placement: { type: :string,  example: 'home_top', description: '展示位置' }
                 },
                 required: %w[id image_key position placement]
               }

        run_test!
      end
    end
  end

  # ── Announcements ─────────────────────────────────────────────────────────

  path '/api/v1/announcements' do
    get '公告列表' do
      tags '内容运营'
      description <<~DESC
        获取当前有效的系统公告列表，按置顶+时间倒序排列。
        - **无需认证**，App 公告中心直接调用
        - 支持 `?locale=` 指定语言（默认 `zh-CN`）
        - 置顶公告（`is_pinned: true`）排在最前
      DESC
      produces 'application/json'

      parameter name: :locale,
                in: :query,
                type: :string,
                required: false,
                description: '语言代码，如 zh-CN / en，默认 zh-CN'

      response '200', '获取成功' do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id:                { type: :integer, example: 1 },
                   title:             { type: :string,  example: '平台升级维护通知' },
                   content:           { type: :string,  example: '系统将于 2026-05-01 00:00–04:00 进行升级维护…' },
                   announcement_type: { type: :string,  example: 'system', enum: %w[system activity promotion] },
                   is_pinned:         { type: :boolean, example: true },
                   created_at:        { type: :string,  format: 'date-time' }
                 },
                 required: %w[id title content announcement_type is_pinned created_at]
               }

        run_test!
      end
    end
  end

  # ── FAQs ──────────────────────────────────────────────────────────────────

  path '/api/v1/faqs' do
    get 'FAQ 分类列表（含问答）' do
      tags '内容运营'
      description <<~DESC
        获取所有启用的 FAQ 分类及其下属问题/答案，按分类排序。
        - **无需认证**，App 帮助中心直接调用
        - 支持 `?locale=` 指定语言（默认 `zh-CN`），内容多语言自动降级
        - 返回树形结构：分类 → 问题列表
      DESC
      produces 'application/json'

      parameter name: :locale,
                in: :query,
                type: :string,
                required: false,
                description: '语言代码，如 zh-CN / en，默认 zh-CN'

      response '200', '获取成功' do
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id:   { type: :integer, example: 1 },
                   name: { type: :string,  example: '订单相关' },
                   slug: { type: :string,  example: 'orders', description: '分类唯一标识符' },
                   faqs: {
                     type: :array,
                     items: {
                       type: :object,
                       properties: {
                         id:       { type: :integer, example: 10 },
                         question: { type: :string,  example: '如何取消订单？' },
                         answer:   { type: :string,  example: '您可以在订单详情页点击「取消订单」按钮…' }
                       },
                       required: %w[id question answer]
                     }
                   }
                 },
                 required: %w[id name slug faqs]
               }

        run_test!
      end
    end
  end
end
