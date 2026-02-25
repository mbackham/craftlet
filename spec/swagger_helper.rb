# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Craftlet API',
        version: 'v1',
        description: 'Craftlet 平台 API 接口文档',
        contact: {
          name: 'Craftlet Team'
        }
      },
      paths: {},
      servers: [
        {
          url: '{protocol}://{host}',
          variables: {
            protocol: { default: 'http', enum: ['http', 'https'] },
            host: { default: 'localhost:3000' }
          }
        }
      ],
      components: {
        securitySchemes: {
          Bearer: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT',
            description: '使用 JWT Token 认证。登录后获取 token，格式: Bearer {token}'
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
