#!/usr/bin/env ruby
# frozen_string_literal: true

# 验证和管理用户锁定状态的辅助脚本

require_relative 'config/environment'

EMAIL = ARGV[0] || '634264926@qq.com'

puts "=" * 60
puts "用户锁定状态检查工具"
puts "=" * 60
puts "检查邮箱: #{EMAIL}"
puts ""

user = User.find_by(email: EMAIL)

if user.nil?
  puts "❌ 未找到该用户"
  puts ""
  puts "创建测试用户? (y/n)"
  print "> "
  
  if STDIN.gets.chomp.downcase == 'y'
    user = User.create!(
      email: EMAIL,
      password: 'password123',
      password_confirmation: 'password123'
    )
    puts "✅ 已创建测试用户"
  else
    exit
  end
end

puts "用户信息:"
puts "-" * 60
puts "ID:              #{user.id}"
puts "Email:           #{user.email}"
puts "失败尝试次数:    #{user.failed_attempts}"
puts "锁定时间:        #{user.locked_at || '未锁定'}"
puts "解锁令牌:        #{user.unlock_token ? '已生成' : '无'}"

if user.access_locked?
  puts ""
  puts "🔒 账户状态:     已锁定"
  puts ""
  
  # 计算剩余锁定时间
  if user.locked_at
    unlock_time = user.locked_at + Devise.unlock_in
    remaining = unlock_time - Time.current
    
    if remaining > 0
      minutes = (remaining / 60).to_i
      seconds = (remaining % 60).to_i
      puts "解锁倒计时:      #{minutes}分#{seconds}秒"
      puts "自动解锁时间:    #{unlock_time.strftime('%Y-%m-%d %H:%M:%S')}"
    else
      puts "⚠️  锁定已超时，但账户仍标记为锁定状态"
    end
  end
  
  puts ""
  puts "解锁选项:"
  puts "1. 手动解锁账户"
  puts "2. 等待自动解锁 (#{Devise.unlock_in / 60}分钟)"
  puts "3. 查看解锁邮件内容 (如果配置了邮件)"
  puts "q. 退出"
  print "> "
  
  choice = STDIN.gets.chomp
  
  case choice
  when '1'
    user.unlock_access!
    puts "✅ 账户已解锁"
    puts "   失败尝试次数已重置为: #{user.reload.failed_attempts}"
  when '2'
    puts "继续等待自动解锁..."
  when '3'
    if user.unlock_token
      puts "解锁链接: http://localhost:3000/users/unlock?unlock_token=#{user.unlock_token}"
    else
      puts "未生成解锁令牌"
    end
  end
else
  puts ""
  puts "✅ 账户状态:     正常"
  puts ""
  
  if user.failed_attempts > 0
    remaining_attempts = Devise.maximum_attempts - user.failed_attempts
    puts "⚠️  警告: 已有 #{user.failed_attempts} 次失败尝试"
    puts "   还剩 #{remaining_attempts} 次尝试机会"
    puts ""
    puts "重置失败计数? (y/n)"
    print "> "
    
    if STDIN.gets.chomp.downcase == 'y'
      user.update(failed_attempts: 0)
      puts "✅ 失败计数已重置"
    end
  end
end

puts ""
puts "=" * 60
puts "Devise Lockable 配置:"
puts "-" * 60
puts "锁定策略:        #{Devise.lock_strategy}"
puts "最大尝试次数:    #{Devise.maximum_attempts}"
puts "解锁策略:        #{Devise.unlock_strategy}"
puts "锁定时长:        #{Devise.unlock_in / 60}分钟"
puts "最后一次警告:    #{Devise.last_attempt_warning ? '启用' : '禁用'}"
puts "=" * 60
