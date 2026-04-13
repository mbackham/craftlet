# frozen_string_literal: true

# Migration: RelaxUserDeviseConstraints
#
# 目的 / Purpose:
#   1. 允许 Logto 创建的用户没有本地密码（encrypted_password 改为 nullable）
#      Allow Logto-created users to have no local password (encrypted_password nullable)
#   2. jti 字段不再强制要求（devise-jwt 将被移除）
#      jti column no longer required (devise-jwt will be removed in Week 1)
#   3. 新增 Logto 用户同步所需字段
#      Add columns required for Logto user synchronization
#
# ⚠️  零风险策略：只添加字段 / 放宽约束，不删除任何现有列。
# ⚠️  Zero-risk strategy: only add columns / relax constraints, never drop existing ones.
#
class RelaxUserDeviseConstraints < ActiveRecord::Migration[7.1]
  def change
    # 1. 允许 encrypted_password 为 NULL（Logto 用户无本地密码）
    #    Allow encrypted_password to be NULL (Logto users have no local password)
    change_column_null :users, :encrypted_password, true
    change_column_default :users, :encrypted_password, from: '', to: nil

    # 2. 允许 jti 为 NULL（devise-jwt 移除后不再写入此字段）
    #    Allow jti to be NULL (no longer written after devise-jwt removal)
    change_column_null :users, :jti, true

    # 3. 新增 Logto 身份绑定字段
    #    Add Logto identity binding columns
    add_column :users, :external_id, :string,
               comment: 'Logto sub claim — 唯一标识 Logto 用户 / Uniquely identifies the Logto user'

    add_column :users, :auth_provider, :string, default: 'logto',
               comment: '认证来源 / Auth source: logto | devise(legacy)'

    # 4. 新增用户本地化偏好字段
    #    Add user locale / region columns
    add_column :users, :locale, :string, default: 'zh-CN',
               comment: '用户界面语言 / UI locale, e.g. zh-CN, en'

    add_column :users, :country_code, :string,
               comment: '用户所在国家 / User country: CN | INTL'

    # 5. external_id 唯一索引（防止 Logto 同一用户重复创建本地记录）
    #    Unique index on external_id (prevents duplicate local records for the same Logto user)
    add_index :users, :external_id, unique: true, name: 'index_users_on_external_id'
  end
end
