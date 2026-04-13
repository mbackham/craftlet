# frozen_string_literal: true

# UuidIdentity — UUID <-> bigint 统一转换 Concern
#
# 背景 / Background:
#   数据库中 17 个 UUID 列（customer_id、merchant_id、bidder_id 等）存储的是
#   User / AdminUser 的 bigint 主键的 UUID 封装格式：
#     00000000-0000-0000-0000-{12 位数字 ID}
#   例：User#42 → "00000000-0000-0000-0000-000000000042"
#
#   The database has 17 UUID columns (customer_id, merchant_id, bidder_id, etc.)
#   that store bigint primary keys of User / AdminUser encoded as UUIDs:
#     00000000-0000-0000-0000-{12-digit numeric ID}
#   e.g. User#42 → "00000000-0000-0000-0000-000000000042"
#
# 用法 / Usage:
#   class Order < ApplicationRecord
#     include UuidIdentity
#   end
#
#   UuidIdentity 模块提供：
#   - id_to_uuid(numeric_id)         bigint → UUID 字符串（写入数据库时用）
#   - uuid_to_id(uuid)               UUID  → bigint（查询时用）
#   - find_user_by_uuid(uuid_value)  根据 UUID 列查找 User
#   - find_admin_by_uuid(uuid_value) 根据 UUID 列查找 AdminUser
#
module UuidIdentity
  extend ActiveSupport::Concern

  # UUID 格式模板 / UUID format template
  UUID_FORMAT = '00000000-0000-0000-0000-%012d'

  class_methods do
    # 将 bigint User/AdminUser ID 转为 UUID 格式字符串（数据库存储格式）
    # Encodes a bigint User/AdminUser ID as a UUID string (for DB storage).
    #
    # @param numeric_id [Integer, String, nil]
    # @return [String, nil]
    #
    # Examples:
    #   User.id_to_uuid(42)  #=> "00000000-0000-0000-0000-000000000042"
    #   User.id_to_uuid(nil) #=> nil
    def id_to_uuid(numeric_id)
      return nil if numeric_id.blank?

      sprintf(UUID_FORMAT, numeric_id.to_i)
    end

    # 将 UUID 格式字符串解码为 bigint ID（数据库查询时用）
    # Decodes a UUID string back to the bigint numeric ID (for DB queries).
    #
    # @param uuid [String, nil]
    # @return [Integer, nil]
    #
    # Examples:
    #   User.uuid_to_id("00000000-0000-0000-0000-000000000042") #=> 42
    #   User.uuid_to_id(nil) #=> nil
    def uuid_to_id(uuid)
      return nil if uuid.blank?

      uuid.to_s.split('-').last.to_i
    end

    # 从 UUID 列值查找 User 记录
    # Finds a User record by a UUID-encoded column value.
    #
    # @param uuid_value [String, nil]
    # @return [User, nil]
    def find_user_by_uuid(uuid_value)
      return nil if uuid_value.blank?

      User.find_by(id: uuid_to_id(uuid_value))
    end

    # 从 UUID 列值查找 AdminUser 记录
    # Finds an AdminUser record by a UUID-encoded column value.
    #
    # @param uuid_value [String, nil]
    # @return [AdminUser, nil]
    def find_admin_by_uuid(uuid_value)
      return nil if uuid_value.blank?

      AdminUser.find_by(id: uuid_to_id(uuid_value))
    end
  end
end
