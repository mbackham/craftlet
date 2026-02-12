#!/bin/bash

# 快速测试 Devise Lockable 功能
# 使用同一账户多次失败登录，然后尝试正确密码

EMAIL="634264926@qq.com"
BASE_URL="http://localhost:3000/api/v1/users/sign_in"

echo "================================================"
echo "Devise Lockable 快速测试"
echo "================================================"
echo "测试邮箱: $EMAIL"
echo "策略: 5次失败尝试后锁定账户"
echo ""

# 失败尝试 5 次
for i in {1..5}; do
  echo "=== 第 $i 次失败尝试 ==="
  curl -s -X POST "$BASE_URL" \
    -H "Content-Type: application/json" \
    -d "{\"user\":{\"email\":\"$EMAIL\",\"password\":\"wrong_password\"}}"
  echo ""
  sleep 0.5
done

echo "================================================"
echo "第 6 次尝试（使用正确密码）"
echo "预期: 应该返回账户已锁定的错误"
echo "================================================"
curl -s -X POST "$BASE_URL" \
  -H "Content-Type: application/json" \
  -d "{\"user\":{\"email\":\"$EMAIL\",\"password\":\"password123\"}}"

echo ""
echo "================================================"
echo "验证步骤："
echo "================================================"
echo "1. 检查上面的响应是否包含 'locked' 或账户锁定信息"
echo ""
echo "2. 查看数据库中的锁定状态："
echo "   rails runner \"puts User.find_by(email: '$EMAIL')&.locked_at\""
echo ""
echo "3. 查看失败尝试次数："
echo "   rails runner \"puts User.find_by(email: '$EMAIL')&.failed_attempts\""
echo ""
echo "4. 解锁账户："
echo "   rails runner \"User.find_by(email: '$EMAIL')&.unlock_access!\""
