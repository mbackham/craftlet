# frozen_string_literal: true

# app/blueprints/base_blueprint.rb
#
# BaseBlueprint — 所有 Blueprint 的基类
# BaseBlueprint — Base class for all blueprints
#
# 提供公共配置：
#   - 时间戳以 ISO 8601 格式输出
#   - id 字段默认包含
#
# Provides shared configuration:
#   - Timestamps output in ISO 8601 format
#   - id field included by default
#
class BaseBlueprint < Blueprinter::Base
  # 统一时间格式：ISO 8601 with timezone
  # Unified time format: ISO 8601 with timezone
  identifier :id

  # 可供子类直接使用的时间格式化方法
  # Time formatting helper available to subclasses
  def self.iso8601(value)
    value&.iso8601
  end
end
