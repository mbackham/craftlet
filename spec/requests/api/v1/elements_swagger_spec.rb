# frozen_string_literal: true

require 'swagger_helper'

# spec/requests/api/v1/elements_swagger_spec.rb
#
# 手串元素库模块 Swagger 文档
# 所有接口公开，无需 JWT 认证
#
# GET /api/v1/elements      — 元素列表（多维过滤 + 排序 + 分页）
# GET /api/v1/elements/:id  — 元素详情

ELEMENT_SCHEMA = {
  type: :object,
  properties: {
    id:                 { type: :integer,  example: 1 },
    name:               { type: :string,   example: '18mm 南红玛瑙圆珠' },
    category:           { type: :string,   example: '玛瑙' },
    element_type:       { type: :string,   example: 'bead',   enum: %w[bead string other] },
    element_type_label: { type: :string,   example: '珠子' },
    material_type: {
      type: :string,
      example: 'agate',
      enum: %w[wood glass hetian_jade jadeite agate crystal amber coral
               lapis turquoise obsidian bodhi bone metal ceramic resin fabric other]
    },
    material_type_label: { type: :string,  example: '玛瑙' },
    finish_type:         { type: :string,  example: 'polished', enum: %w[matte glossy frosted carved polished] },
    color_hex:           { type: :string,  example: '#C0392B',  description: '十六进制颜色值' },
    color_name:          { type: :string,  example: '朱砂红' },
    size_mm:             { type: :number,  format: 'float', example: 18.0, description: '直径，单位 mm' },
    weight_g:            { type: :number,  format: 'float', example: 3.5,  description: '重量，单位 g' },
    hole_diameter_mm:    { type: :number,  format: 'float', example: 1.2,  description: '孔径，单位 mm' },
    hardness_level:      { type: :integer, example: 7,  description: '莫氏硬度（1–10）' },
    is_natural:          { type: :boolean, example: true, description: '是否天然材质' },
    origin_region:       { type: :string,  example: '云南' },
    description:         { type: :string,  example: '产自云南保山，色泽鲜艳，油脂感强。' },
    oss_key:             { type: :string,  example: 'elements/agate_18mm.jpg',   description: '主图 OSS Key' },
    thumbnail_key:       { type: :string,  example: 'elements/agate_18mm_th.jpg', description: '缩略图 OSS Key' },
    mesh_url:            { type: :string,  example: 'https://cdn.craftlet.com/meshes/agate_18mm.glb', description: '3D 网格预览 URL' },
    glb_key:             { type: :string,  example: 'elements/agate_18mm.glb',   description: 'GLB 模型 OSS Key' },
    tags:                { type: :array,   items: { type: :string }, example: %w[南红 18mm 圆珠], description: '标签列表' },
    status:              { type: :string,  example: 'on_shelf', enum: %w[draft on_shelf off_shelf] },
    price:               { type: :string,  example: '12.50', description: '单价（字符串，保留小数）' },
    shelved_at:          { type: :string,  format: 'date-time', example: '2026-01-15T08:00:00Z' },
    created_at:          { type: :string,  format: 'date-time', example: '2026-01-10T12:00:00Z' }
  },
  required: %w[id name element_type material_type status price created_at]
}.freeze

RSpec.describe '元素库 API (公开)', type: :request do
  # ── GET /api/v1/elements ───────────────────────────────────────────────────

  path '/api/v1/elements' do
    get '元素列表' do
      tags '元素库'
      description <<~DESC
        获取已上架的手串元素列表，支持多维度过滤、排序与分页。
        - **无需认证**，直接调用
        - 仅返回状态为 `on_shelf` 的元素
        - 默认按 `created_at` 倒序，每页 20 条，最多 100 条
      DESC
      produces 'application/json'

      parameter name: :element_type,
                in: :query,
                type: :string,
                required: false,
                enum: %w[bead string other],
                description: '元素类型过滤：bead（珠子）/ string（线绳）/ other（配件）'

      parameter name: :material_type,
                in: :query,
                type: :string,
                required: false,
                enum: %w[wood glass hetian_jade jadeite agate crystal amber coral
                         lapis turquoise obsidian bodhi bone metal ceramic resin fabric other],
                description: '材质类型过滤'

      parameter name: :color_hex,
                in: :query,
                type: :string,
                required: false,
                description: '颜色精确匹配，如 #C0392B'

      parameter name: :size_min,
                in: :query,
                type: :number,
                required: false,
                description: '最小直径（mm），大于等于'

      parameter name: :size_max,
                in: :query,
                type: :number,
                required: false,
                description: '最大直径（mm），小于等于'

      parameter name: :price_max,
                in: :query,
                type: :number,
                required: false,
                description: '最高单价（元），小于等于'

      parameter name: :origin_region,
                in: :query,
                type: :string,
                required: false,
                description: '产地过滤，如 云南'

      parameter name: :tag,
                in: :query,
                type: :string,
                required: false,
                description: '标签过滤，包含该标签的元素（单个标签）'

      parameter name: :is_natural,
                in: :query,
                type: :boolean,
                required: false,
                description: '是否天然材质过滤'

      parameter name: :sort,
                in: :query,
                type: :string,
                required: false,
                enum: %w[price size_mm created_at shelved_at name],
                description: '排序字段，默认 created_at'

      parameter name: :direction,
                in: :query,
                type: :string,
                required: false,
                enum: %w[asc desc],
                description: '排序方向，默认 desc'

      parameter name: :page,
                in: :query,
                type: :integer,
                required: false,
                description: '页码，默认 1'

      parameter name: :per_page,
                in: :query,
                type: :integer,
                required: false,
                description: '每页数量，默认 20，最大 100'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: ELEMENT_SCHEMA
                 },
                 meta: {
                   type: :object,
                   description: '分页元信息',
                   properties: {
                     current_page: { type: :integer, example: 1 },
                     total_pages:  { type: :integer, example: 5 },
                     total_count:  { type: :integer, example: 98 },
                     per_page:     { type: :integer, example: 20 }
                   }
                 }
               }

        run_test!
      end
    end
  end

  # ── GET /api/v1/elements/:id ───────────────────────────────────────────────

  path '/api/v1/elements/{id}' do
    get '元素详情' do
      tags '元素库'
      description <<~DESC
        获取单个已上架元素的完整信息。
        - **无需认证**，直接调用
        - 仅返回状态为 `on_shelf` 的元素，否则返回 404
      DESC
      produces 'application/json'

      parameter name: :id,
                in: :path,
                type: :integer,
                required: true,
                description: '元素 ID'

      response '200', '获取成功' do
        schema type: :object,
               properties: {
                 data: ELEMENT_SCHEMA
               }

        run_test!
      end

      response '404', '元素不存在或已下架' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Record not found' }
               }

        run_test!
      end
    end
  end
end
