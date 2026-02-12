#!/bin/bash

# 快速测试 Rack::Attack 限流功能
# 使用同一IP快速发送多次请求

BASE_URL="http://localhost:3000/api/v1/users/sign_in"

echo "================================================"
echo "Rack::Attack IP 限流快速测试"
echo "================================================"
echo "策略: 同一IP 5分钟内最多 5 次登录尝试"
echo ""

# 快速发送 6 次请求（使用不同邮箱避免 Devise lockable 干扰）
for i in {1..6}; do
  EMAIL="test_user_$i@example.com"
  echo "=== 第 $i 次请求 (Email: $EMAIL) ==="
  
  RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$BASE_URL" \
    -H "Content-Type: application/json" \
    -d "{\"user\":{\"email\":\"$EMAIL\",\"password\":\"wrong_password\"}}")
  
  HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
  BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE/d')
  
  echo "HTTP状态码: $HTTP_CODE"
  echo "$BODY"
  
  if [ "$HTTP_CODE" = "429" ]; then
    echo ""
    echo "✅ 成功! Rack::Attack 在第 $i 次请求时触发了限流"
    echo "   响应状态码: 429 Too Many Requests"
    break
  fi
  echo ""
done

echo ""
echo "================================================"
echo "验证步骤："
echo "================================================"
echo "1. 检查 Rails 日志中的 Rack::Attack 警告："
echo "   tail -n 50 log/development.log | grep 'Rack::Attack'"
echo ""
echo "2. 如果要重新测试，需要等待 5 分钟或重启服务器清除缓存："
echo "   (Rack::Attack 使用 MemoryStore，重启会清除)"
