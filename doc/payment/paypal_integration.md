# PayPal 接入方案预研

## 1. 业务流程梳理
当前系统为 C2C/B2C 混合电商模式。买家下单后使用 PayPal 支付，款项需进入平台账户（或进行分账）。卖家发货、买家确认收货后，订单完结。如发生退款，需原路退回到买家 PayPal 账户。

### 核心节点
1. **订单支付**：买家在前端使用 PayPal Checkout 支付。
2. **支付结果确认**：通过 Webhook 和服务端主动查询双重确认支付结果。
3. **退款处理**：运营在后台发起退款，调用 PayPal Refund API。

## 2. 支付接入 (PayPal Checkout SDK)
推荐使用 **PayPal JS SDK (Smart Payment Buttons)** 结合 **Orders V2 API**。

### 前端流程 (JS SDK)
1. 引入 PayPal JS SDK: `<script src="https://www.paypal.com/sdk/js?client-id=YOUR_CLIENT_ID&currency=USD"></script>`
2. 渲染支付按钮：
```html
<div id="paypal-button-container"></div>
<script>
  paypal.Buttons({
    createOrder: function() {
      // 请求后端业务接口，后端调用 PayPal API 创建 Order，返回 PayPal Order ID
      return fetch('/api/v1/payments/paypal/create_order', { method: 'POST' })
        .then(res => res.json())
        .then(orderData => orderData.id);
    },
    onApprove: function(data, actions) {
      // 支付完成后，通知后端去 Capture(扣款)
      return fetch(`/api/v1/payments/paypal/capture_order`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ order_id: data.orderID })
      }).then(res => res.json()).then(orderData => {
        // 支付成功展示
      });
    }
  }).render('#paypal-button-container');
</script>
```

### 服务端流程 (Orders V2 API)
- **依赖 Gem**: `paypal-checkout-sdk` 或自行封装 HTTP 客户端调用。
- **创建 Order**: `/v2/checkout/orders` (Intent: CAPTURE)
- **捕获支付(Capture)**: `/v2/checkout/orders/{id}/capture`

## 3. 退款接入 (Refund API)
退款基于支付成功后生成的 `capture_id`（不是 order_id）。

### 服务端流程 (Payments V2 API)
- **Endpoint**: `POST /v2/payments/captures/{capture_id}/refund`
- **Request Body**:
```json
{
  "amount": {
    "value": "10.00",
    "currency_code": "USD"
  },
  "invoice_id": "YOUR_REFUND_SYSTEM_ID",
  "note_to_payer": "Refund for out of stock"
}
```
- 可以全额退款或部分退款。接口响应会返回 `refund_id`，用于后续状态查询（如状态为 `PENDING`，需依赖 Webhook 通知 `COMPLETED`）。

## 4. Webhook 机制与事件处理
为了防止前端丢单或由于网络问题导致没有在 `onApprove` 里通知后端，必须接入 Webhook 接收异步通知。同时，退款的最终状态也需要 Webhook。

### 需要订阅的核心事件 (Event Types)
- **`PAYMENT.CAPTURE.COMPLETED`**: 扣款成功，业务上将订单更新为“已支付”。
- **`PAYMENT.CAPTURE.DENIED`**: 扣款被拒绝。
- **`PAYMENT.CAPTURE.REFUNDED`**: 退款成功，业务上更新退款单和订单状态。

### Webhook 验签 (Webhook Signatures)
安全至上。在处理 Webhook 之前，必须调用 PayPal 的验签接口：
- **Endpoint**: `POST /v1/notifications/verify-webhook-signature`
- **步骤**：将收到的 Headers (`paypal-auth-algo`, `paypal-cert-url`, `paypal-transmission-id`, `paypal-transmission-sig`, `paypal-transmission-time`) 连同请求体一起发给 PayPal 验证。

## 5. 常见坑点与注意事项
1. **沙盒与生产环境隔离**：必须配置独立的两套 `client_id` 和 `client_secret`。
2. **币种问题**：PayPal 支持多种法币，需防范汇率和币种不匹配。创建 Order 时必须明确指定 `currency_code` (如 USD)。不支持 CNY。
3. **幂等性 (Idempotency)**：
   - PayPal API 强制要求在头信息中传入 `PayPal-Request-Id` 实现幂等。
   - 退款、Capture 等关键操作必须带上系统的唯一标识作为 `PayPal-Request-Id`，防止重试导致重复扣款或退款。
4. **延迟到达的 Webhook**：可能出现前端已完成 Capture 并通知业务系统，Webhook 才到达的情况。业务系统处理事件时注意并发锁（乐观锁/悲观锁）和状态流转的幂等性校验。
