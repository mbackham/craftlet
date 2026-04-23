# Craftlet RN App — 架构设计文档

> 基于后端 Rails API v1 分析生成。后端地址：`/api/v1`，统一响应格式 `{ success, data, meta }`。

---

## 目录

1. [技术选型](#1-技术选型)
2. [目录结构](#2-目录结构)
3. [认证方案（Logto）](#3-认证方案logto)
4. [API 层设计](#4-api-层设计)
5. [状态管理](#5-状态管理)
6. [文件上传方案](#6-文件上传方案)
7. [支付方案（微信 + 支付宝）](#7-支付方案微信--支付宝)
8. [实时功能（WebSocket + 推送）](#8-实时功能websocket--推送)
9. [路由结构](#9-路由结构)
10. [表单方案](#10-表单方案)
11. [构建与发布](#11-构建与发布)
12. [环境变量](#12-环境变量)

---

## 1. 技术选型

### 核心依赖

| 功能 | 包 | 理由 |
|---|---|---|
| 框架 | `expo` (SDK 51+) | 托管构建、上架方便 |
| 路由 | `expo-router` v3 | 文件路由，贴合 Expo |
| 认证 | `@logto/rn` | 与后端 JWT 机制一致 |
| 状态（全局） | `zustand` | 轻量，无样板代码 |
| 状态（服务端） | `@tanstack/react-query` v5 | 缓存、重试、分页 |
| 网络请求 | `axios` | 拦截器方便挂 JWT |
| UI 组件 | `react-native-paper` | Material 风格，稳定 |
| 表单 | `react-hook-form` + `zod` | 校验友好 |
| 图片展示 | `expo-image` | 带缓存，性能优 |
| 图片选择 | `expo-image-picker` | Expo 官方 |
| 敏感存储 | `expo-secure-store` | Token 存储 |
| 通用存储 | `@react-native-async-storage/async-storage` | 非敏感缓存 |
| 图标 | `@expo/vector-icons` | 内置 Expo |
| WebSocket | `@rails/actioncable` | 与后端 ActionCable 对接 |
| 推送通知 | `expo-notifications` | Expo Push 服务 |
| 微信支付 | `react-native-wechat-lib` | 需 custom dev build |
| 支付宝 | `@uiw/react-native-alipay` | 需 custom dev build |
| 监控 | `@sentry/react-native` | 崩溃 + 埋点 |
| 统计 | `mixpanel-react-native` | 用户行为分析 |
| 测试 | `jest` + `@testing-library/react-native` | 单测 |

> **重要**：微信/支付宝 SDK 包含原生模块，**必须使用 `expo-dev-client` custom build**，无法在 Expo Go 中运行。

---

## 2. 目录结构

```
craftlet-app/
├── app/                          # expo-router 文件路由
│   ├── _layout.tsx               # 根布局（字体、主题、QueryClient、Sentry）
│   ├── (auth)/                   # 未登录区域（不挂 JWT 守卫）
│   │   ├── _layout.tsx
│   │   └── login.tsx             # Logto 登录入口
│   ├── (tabs)/                   # 主 Tab 区域（已登录）
│   │   ├── _layout.tsx           # Tab 导航配置
│   │   ├── index.tsx             # 首页（Banner + 订单入口）
│   │   ├── orders/
│   │   │   ├── index.tsx         # 订单列表
│   │   │   ├── create.tsx        # 下单（含图片上传）
│   │   │   └── [id]/
│   │   │       ├── index.tsx     # 订单详情
│   │   │       ├── bids.tsx      # 查看报价列表
│   │   │       └── pay.tsx       # 支付页
│   │   ├── notifications.tsx     # 通知中心
│   │   └── profile/
│   │       ├── index.tsx         # 个人资料
│   │       └── edit.tsx          # 编辑资料（含头像上传）
│   ├── merchant/                 # 商家区域（角色守卫）
│   │   ├── _layout.tsx
│   │   ├── apply.tsx             # 商家入驻（证件上传）
│   │   ├── dashboard.tsx         # 商家看板
│   │   ├── orders/
│   │   │   ├── index.tsx         # 商家订单列表
│   │   │   └── [id].tsx          # 订单详情（报价 + 操作）
│   │   └── settlements/
│   │       └── index.tsx         # 结算记录
│   └── support/
│       ├── tickets/
│       │   ├── index.tsx         # 工单列表
│       │   ├── create.tsx        # 提交工单
│       │   └── [id].tsx          # 工单详情 + 追加消息
│       └── feedback.tsx          # 匿名反馈（无需登录）
├── src/
│   ├── api/                      # API 层
│   │   ├── client.ts             # axios 实例 + 拦截器
│   │   ├── endpoints/            # 按业务拆分的请求函数
│   │   │   ├── auth.ts
│   │   │   ├── orders.ts
│   │   │   ├── payments.ts
│   │   │   ├── notifications.ts
│   │   │   ├── merchant.ts
│   │   │   ├── tickets.ts
│   │   │   ├── upload.ts
│   │   │   └── content.ts
│   │   └── types.ts              # 接口响应类型定义
│   ├── hooks/                    # React Query hooks
│   │   ├── useOrders.ts
│   │   ├── useOrderDetail.ts
│   │   ├── useBids.ts
│   │   ├── useNotifications.ts
│   │   ├── useMerchant.ts
│   │   └── useUpload.ts
│   ├── stores/                   # Zustand stores
│   │   ├── authStore.ts          # 用户信息 + Token
│   │   ├── notificationStore.ts  # 未读数、实时推送
│   │   └── orderDraftStore.ts    # 下单草稿（临时状态）
│   ├── services/
│   │   ├── cable.ts              # ActionCable 连接管理
│   │   ├── payment.ts            # 微信/支付宝调起封装
│   │   └── push.ts               # 推送注册与处理
│   ├── components/               # 通用组件
│   │   ├── ImageUploader.tsx     # 图片选择 + 上传组件
│   │   ├── OrderCard.tsx
│   │   ├── BidItem.tsx
│   │   └── PaginatedList.tsx     # 无限滚动列表
│   ├── schemas/                  # zod 校验 schema
│   │   ├── orderSchema.ts
│   │   ├── merchantApplySchema.ts
│   │   └── profileSchema.ts
│   ├── constants/
│   │   ├── queryKeys.ts          # React Query key 常量
│   │   └── config.ts             # 全局配置
│   └── utils/
│       ├── formatCurrency.ts
│       └── formatDate.ts
├── assets/
├── app.json
├── eas.json
└── .env                          # 环境变量（不提交 git）
```

---

## 3. 认证方案（Logto）

### 流程图

```
用户点击「登录」
      │
      ▼
@logto/rn 打开 Logto 授权页（WebBrowser）
      │
      ▼
用户完成登录（短信/邮箱/社交）
      │
      ▼
Logto 回调，@logto/rn 拿到 access_token（RS256 JWT）
      │
      ▼
将 access_token 存入 expo-secure-store
      │
      ▼
后续所有 API 请求 Header: Authorization: Bearer <token>
      │
      ▼
后端验证 JWT → 自动同步/创建本地用户
```

### 实现

```typescript
// src/stores/authStore.ts
import { create } from 'zustand'
import * as SecureStore from 'expo-secure-store'

interface AuthState {
  token: string | null
  user: UserProfile | null
  setToken: (token: string) => void
  clearAuth: () => void
}

export const useAuthStore = create<AuthState>((set) => ({
  token: null,
  user: null,
  setToken: (token) => {
    SecureStore.setItemAsync('access_token', token)
    set({ token })
  },
  clearAuth: () => {
    SecureStore.deleteItemAsync('access_token')
    set({ token: null, user: null })
  },
}))
```

```typescript
// app/(auth)/login.tsx
import { useLogto } from '@logto/rn'

export default function LoginScreen() {
  const { signIn } = useLogto()
  return (
    <Button onPress={() => signIn('craftlet://callback')}>
      登录 / 注册
    </Button>
  )
}
```

```typescript
// app/_layout.tsx — Token 刷新 + 守卫
import { LogtoProvider, LogtoConfig } from '@logto/rn'

const logtoConfig: LogtoConfig = {
  endpoint: process.env.EXPO_PUBLIC_LOGTO_ENDPOINT!,
  appId: process.env.EXPO_PUBLIC_LOGTO_APP_ID!,
}

export default function RootLayout() {
  return (
    <LogtoProvider config={logtoConfig}>
      <QueryClientProvider client={queryClient}>
        <AuthGuard />
      </QueryClientProvider>
    </LogtoProvider>
  )
}
```

### Token 过期处理

axios 响应拦截器捕获 401 → 调用 `@logto/rn` 的 `getAccessToken()`（自动刷新）→ 重试原请求。

---

## 4. API 层设计

### axios 实例 + 拦截器

```typescript
// src/api/client.ts
import axios from 'axios'
import { useAuthStore } from '@/stores/authStore'

export const apiClient = axios.create({
  baseURL: process.env.EXPO_PUBLIC_API_BASE_URL,
  timeout: 15_000,
  headers: { 'Content-Type': 'application/json' },
})

// 请求拦截：自动挂 JWT
apiClient.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// 响应拦截：解包 { success, data, meta }，统一处理错误
apiClient.interceptors.response.use(
  (response) => response.data,  // 直接返回 data 字段
  (error) => {
    const { status, data } = error.response ?? {}
    if (status === 401) useAuthStore.getState().clearAuth()
    return Promise.reject({
      code: data?.error?.code ?? 'unknown',
      message: data?.error?.message ?? '请求失败',
      status,
    })
  }
)
```

### 后端响应类型定义

```typescript
// src/api/types.ts

// 后端统一响应信封
interface ApiSuccess<T> {
  success: true
  data: T
  meta?: PaginationMeta
}

interface PaginationMeta {
  current_page: number
  total_pages: number
  total_count: number
  per_page: number
}

// 核心业务类型
interface Order {
  id: number
  order_no: string
  status: 'created' | 'paid' | 'accepted' | 'producing' | 'delivered' | 'cancelled'
  total_amount: string
  currency: string
  merchant_id: string
  created_at: string
}

interface Bid {
  id: number
  amount: string
  status: 'pending' | 'accepted' | 'rejected'
  message: string | null
  created_at: string
}

interface Payment {
  id: number
  channel: 'wechat' | 'alipay'
  status: 'pending' | 'paid' | 'failed' | 'refunded'
  amount: string
  pay_params: Record<string, string>  // 传给原生 SDK 的参数
}
```

### React Query Hooks 示例

```typescript
// src/hooks/useOrders.ts
import { useInfiniteQuery } from '@tanstack/react-query'
import { QUERY_KEYS } from '@/constants/queryKeys'
import { apiClient } from '@/api/client'

export function useOrders() {
  return useInfiniteQuery({
    queryKey: QUERY_KEYS.orders.list(),
    queryFn: ({ pageParam = 1 }) =>
      apiClient.get('/api/v1/orders', { params: { page: pageParam } }),
    getNextPageParam: (lastPage) => {
      const { current_page, total_pages } = lastPage.meta
      return current_page < total_pages ? current_page + 1 : undefined
    },
    staleTime: 30_000,
  })
}
```

```typescript
// src/constants/queryKeys.ts
export const QUERY_KEYS = {
  orders: {
    list: () => ['orders'] as const,
    detail: (id: number) => ['orders', id] as const,
    bids: (orderId: number) => ['orders', orderId, 'bids'] as const,
  },
  notifications: {
    list: () => ['notifications'] as const,
  },
  merchant: {
    profile: () => ['merchant', 'profile'] as const,
    dashboard: () => ['merchant', 'dashboard'] as const,
    orders: () => ['merchant', 'orders'] as const,
  },
}
```

---

## 5. 状态管理

### 职责划分原则

```
Zustand（客户端持久状态）     React Query（服务端数据）
────────────────────────     ──────────────────────────
Token / 用户信息              订单列表 / 订单详情
未读通知数（实时更新）          商家数据
下单草稿（图片key、备注）       通知列表
支付进行中标记                 Bids / Settlements
```

### 通知 Store（配合 WebSocket）

```typescript
// src/stores/notificationStore.ts
import { create } from 'zustand'

interface NotificationState {
  unreadCount: number
  incrementUnread: () => void
  resetUnread: () => void
}

export const useNotificationStore = create<NotificationState>((set) => ({
  unreadCount: 0,
  incrementUnread: () => set((s) => ({ unreadCount: s.unreadCount + 1 })),
  resetUnread: () => set({ unreadCount: 0 }),
}))
```

---

## 6. 文件上传方案

### 流程

```
用户选择图片（expo-image-picker）
          │
          ▼
POST /api/v1/upload/presign
{ content_type, file_size, purpose }
          │
          ▼
后端返回 { presigned_url, object_key, expires_in: 900 }
          │
          ▼
直接 PUT 到 S3（presigned_url）
Headers: Content-Type: image/jpeg
Body: 图片二进制
          │
          ▼
S3 返回 200 → 上传成功
          │
          ▼
将 object_key 保存到业务字段
（如 avatar_key、license_file_key、order_attachment_key）
          │
          ▼
PATCH /api/v1/users/profile { avatar_key: object_key }
```

### 通用上传 Hook

```typescript
// src/hooks/useUpload.ts
import * as ImagePicker from 'expo-image-picker'
import { apiClient } from '@/api/client'

type UploadPurpose = 'avatar' | 'merchant_license' | 'merchant_idcard' | 'order_attachment'

export function useUpload() {
  const [uploading, setUploading] = useState(false)

  const pickAndUpload = async (purpose: UploadPurpose): Promise<string | null> => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 0.8,
      allowsEditing: true,
    })

    if (result.canceled) return null
    const asset = result.assets[0]

    setUploading(true)
    try {
      // Step 1: 获取预签名 URL
      const { data } = await apiClient.post('/api/v1/upload/presign', {
        content_type: asset.mimeType ?? 'image/jpeg',
        file_size: asset.fileSize ?? 0,
        purpose,
      })

      // Step 2: 直传 S3
      const blob = await fetch(asset.uri).then((r) => r.blob())
      await fetch(data.presigned_url, {
        method: 'PUT',
        headers: { 'Content-Type': asset.mimeType ?? 'image/jpeg' },
        body: blob,
      })

      // Step 3: 返回 object_key，调用方保存到业务字段
      return data.object_key
    } finally {
      setUploading(false)
    }
  }

  return { pickAndUpload, uploading }
}
```

### ImageUploader 组件

```typescript
// src/components/ImageUploader.tsx
export function ImageUploader({ purpose, value, onChange }: Props) {
  const { pickAndUpload, uploading } = useUpload()

  const handlePress = async () => {
    const key = await pickAndUpload(purpose)
    if (key) onChange(key)
  }

  return (
    <TouchableOpacity onPress={handlePress} disabled={uploading}>
      {value ? (
        <Image source={{ uri: `${CDN_BASE}/${value}` }} style={styles.preview} />
      ) : (
        <View style={styles.placeholder}>
          {uploading ? <ActivityIndicator /> : <Icon name="camera" />}
        </View>
      )}
    </TouchableOpacity>
  )
}
```

> `CDN_BASE` = S3 Bucket 的 CDN 域名，配置在 `EXPO_PUBLIC_CDN_BASE_URL`。

---

## 7. 支付方案（微信 + 支付宝）

### 整体流程

```
用户在支付页点击「微信支付」/「支付宝支付」
          │
          ▼
POST /api/v1/payments
{ order_id, channel: 'wechat' | 'alipay' }
          │
          ▼
后端返回 { payment_id, pay_params, ... }
          │
          ▼
调起原生 SDK（微信 / 支付宝）
          │
          ├── 用户完成支付
          │         │
          │         ▼
          │   轮询 GET /api/v1/payments/:id/status
          │   或监听 WebSocket OrderStatusChannel
          │         │
          │         ▼
          │   status === 'paid' → 跳转成功页
          │
          └── 用户取消 → 留在支付页，可重试
```

### 微信支付

```typescript
// src/services/payment.ts
import { pay as wechatPay } from 'react-native-wechat-lib'

export async function invokeWechatPay(payParams: WechatPayParams): Promise<boolean> {
  const result = await wechatPay({
    partnerId: payParams.partnerid,
    prepayId: payParams.prepayid,
    nonceStr: payParams.noncestr,
    timeStamp: payParams.timestamp,
    sign: payParams.sign,
    package: payParams.package,
  })
  return result.errCode === 0
}
```

```typescript
// app/(tabs)/orders/[id]/pay.tsx
const handlePay = async (channel: 'wechat' | 'alipay') => {
  const { data } = await apiClient.post('/api/v1/payments', {
    order_id: orderId,
    channel,
  })

  let success = false
  if (channel === 'wechat') {
    success = await invokeWechatPay(data.pay_params)
  } else {
    success = await invokeAlipay(data.pay_params.alipay_sdk_param)
  }

  if (success) {
    // 轮询确认（最多 10 次，每次间隔 2 秒）
    await pollPaymentStatus(data.payment_id)
  }
}

async function pollPaymentStatus(paymentId: number, retries = 10) {
  for (let i = 0; i < retries; i++) {
    await sleep(2000)
    const { data } = await apiClient.get(`/api/v1/payments/${paymentId}/status`)
    if (data.status === 'paid') {
      router.replace(`/orders/${orderId}`)
      return
    }
  }
  // 超时提示用户手动刷新
}
```

### 必须使用 Custom Dev Build

微信/支付宝 SDK 包含原生模块，`eas.json` 需配置：

```json
{
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal"
    },
    "production": {}
  }
}
```

iOS `app.json` 还需配置微信 URL Scheme：

```json
{
  "expo": {
    "ios": {
      "infoPlist": {
        "LSApplicationQueriesSchemes": ["weixin", "weixinULAPI", "alipays", "alipay"]
      }
    },
    "scheme": "craftlet"
  }
}
```

---

## 8. 实时功能（WebSocket + 推送）

### ActionCable 连接

后端提供两个 Channel：
- `NotificationsChannel` — 用户维度的实时通知
- `OrderStatusChannel` — 单订单状态变更

```typescript
// src/services/cable.ts
import { createConsumer } from '@rails/actioncable'
import { useAuthStore } from '@/stores/authStore'

let consumer: ReturnType<typeof createConsumer> | null = null

export function getCableConsumer() {
  if (consumer) return consumer
  const token = useAuthStore.getState().token
  const url = `${process.env.EXPO_PUBLIC_WS_URL}?token=${token}`
  consumer = createConsumer(url)
  return consumer
}

export function disconnectCable() {
  consumer?.disconnect()
  consumer = null
}

// 订阅通知 Channel（在 App 根布局 mount 后调用）
export function subscribeNotifications(
  onReceived: (data: { title: string; body: string }) => void
) {
  return getCableConsumer().subscriptions.create(
    { channel: 'NotificationsChannel' },
    { received: onReceived }
  )
}

// 订阅订单状态（在订单详情页 mount 后调用）
export function subscribeOrderStatus(
  orderId: number,
  onReceived: (data: { status: string }) => void
) {
  return getCableConsumer().subscriptions.create(
    { channel: 'OrderStatusChannel', order_id: orderId },
    { received: onReceived }
  )
}
```

### 在页面中使用

```typescript
// app/(tabs)/orders/[id]/index.tsx
useEffect(() => {
  const sub = subscribeOrderStatus(orderId, ({ status }) => {
    // 让 React Query 重新拉取最新数据
    queryClient.invalidateQueries(QUERY_KEYS.orders.detail(orderId))
  })
  return () => sub.unsubscribe()
}, [orderId])
```

### Expo Push Notifications

```typescript
// src/services/push.ts
import * as Notifications from 'expo-notifications'
import * as Device from 'expo-device'
import { apiClient } from '@/api/client'

export async function registerPushToken() {
  if (!Device.isDevice) return  // 模拟器跳过

  const { status } = await Notifications.requestPermissionsAsync()
  if (status !== 'granted') return

  const { data: token } = await Notifications.getExpoPushTokenAsync({
    projectId: process.env.EXPO_PUBLIC_EAS_PROJECT_ID,
  })

  // 注册到后端
  await apiClient.post('/api/v1/users/device_tokens', {
    token,
    platform: Platform.OS,  // 'ios' | 'android'
  })
}
```

> 后端已集成 `exponent-server-sdk`，Token 注册后即可收到后端主动推送的通知。

---

## 9. 路由结构

基于 `expo-router` 文件路由，认证守卫在 `_layout.tsx` 层实现。

```
/                   → (tabs)/index.tsx      首页
/orders             → (tabs)/orders/index   订单列表
/orders/create      → (tabs)/orders/create  下单页
/orders/:id         → (tabs)/orders/[id]    订单详情
/orders/:id/bids    → (tabs)/orders/[id]/bids  报价列表
/orders/:id/pay     → (tabs)/orders/[id]/pay   支付页
/notifications      → (tabs)/notifications  通知中心
/profile            → (tabs)/profile/index  个人资料
/profile/edit       → (tabs)/profile/edit   编辑资料
/merchant           → merchant/dashboard    商家看板（需商家角色）
/merchant/apply     → merchant/apply        商家入驻
/merchant/orders    → merchant/orders/index 商家订单
/merchant/orders/:id → merchant/orders/[id] 商家订单详情
/support/tickets    → support/tickets/index 工单列表
/support/tickets/:id → support/tickets/[id] 工单详情
/login              → (auth)/login          登录（未登录时重定向）
```

### 认证守卫

```typescript
// app/(tabs)/_layout.tsx
import { Redirect } from 'expo-router'
import { useAuthStore } from '@/stores/authStore'

export default function TabLayout() {
  const token = useAuthStore((s) => s.token)
  if (!token) return <Redirect href="/login" />

  return (
    <Tabs>
      <Tabs.Screen name="index" options={{ title: '首页' }} />
      <Tabs.Screen name="orders" options={{ title: '订单' }} />
      <Tabs.Screen name="notifications" options={{ title: '通知' }} />
      <Tabs.Screen name="profile" options={{ title: '我的' }} />
    </Tabs>
  )
}
```

### 商家角色守卫

```typescript
// app/merchant/_layout.tsx
export default function MerchantLayout() {
  const user = useAuthStore((s) => s.user)
  if (user?.role !== 'merchant') return <Redirect href="/" />
  return <Stack />
}
```

---

## 10. 表单方案

所有表单统一使用 `react-hook-form` + `zod`。

### 示例：下单表单

```typescript
// src/schemas/orderSchema.ts
import { z } from 'zod'

export const orderSchema = z.object({
  merchant_id: z.string().uuid('请选择商家'),
  total_amount: z
    .string()
    .regex(/^\d+(\.\d{1,2})?$/, '金额格式不正确')
    .refine((v) => parseFloat(v) > 0, '金额必须大于 0'),
  currency: z.enum(['CNY', 'USD']).default('CNY'),
  description: z.string().min(10, '请描述至少 10 个字').max(500),
  attachment_key: z.string().optional(),  // 上传后的 S3 object_key
})

export type OrderFormData = z.infer<typeof orderSchema>
```

```typescript
// app/(tabs)/orders/create.tsx
import { useForm, Controller } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'

export default function CreateOrderScreen() {
  const { control, handleSubmit, setValue, formState: { errors } } = useForm<OrderFormData>({
    resolver: zodResolver(orderSchema),
  })

  const { mutate: createOrder, isPending } = useMutation({
    mutationFn: (data: OrderFormData) => apiClient.post('/api/v1/orders', { order: data }),
    onSuccess: ({ data }) => router.push(`/orders/${data.id}`),
  })

  return (
    <ScrollView>
      <Controller
        control={control}
        name="description"
        render={({ field: { onChange, value } }) => (
          <TextInput
            label="手串描述（材质、尺寸、风格）"
            value={value}
            onChangeText={onChange}
            error={!!errors.description}
          />
        )}
      />
      {/* 图片上传 */}
      <ImageUploader
        purpose="order_attachment"
        value={watch('attachment_key')}
        onChange={(key) => setValue('attachment_key', key)}
      />
      <Button onPress={handleSubmit((d) => createOrder(d))} loading={isPending}>
        提交订单
      </Button>
    </ScrollView>
  )
}
```

### 后端错误映射到表单字段

后端返回 `validation_error` 时，可将字段级错误映射回 `setError`：

```typescript
onError: (err) => {
  if (err.code === 'validation_error' && err.fields) {
    Object.entries(err.fields).forEach(([field, msg]) => {
      setError(field as keyof OrderFormData, { message: msg })
    })
  }
}
```

---

## 11. 构建与发布

### EAS 配置（`eas.json`）

```json
{
  "cli": { "version": ">= 7.0.0" },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "env": { "EXPO_PUBLIC_API_BASE_URL": "http://localhost:3000" }
    },
    "preview": {
      "distribution": "internal",
      "env": { "EXPO_PUBLIC_API_BASE_URL": "https://staging-api.craftlet.com" }
    },
    "production": {
      "env": { "EXPO_PUBLIC_API_BASE_URL": "https://api.craftlet.com" }
    }
  },
  "submit": {
    "production": {
      "ios": { "appleId": "your@email.com" },
      "android": { "serviceAccountKeyPath": "./google-service-account.json" }
    }
  }
}
```

### 热更新（eas update）

```bash
# 发布热更新（无需重新审核，修改 JS 层即可）
eas update --branch production --message "修复支付状态轮询"
```

> **注意**：涉及原生模块变更（如新增 SDK、修改 `app.json` 的 `infoPlist`）必须走完整构建流程，不能热更新。

---

## 12. 环境变量

```bash
# .env（不提交 git，通过 EAS Secrets 管理）

# API
EXPO_PUBLIC_API_BASE_URL=http://localhost:3000
EXPO_PUBLIC_WS_URL=ws://localhost:3000/cable
EXPO_PUBLIC_CDN_BASE_URL=https://your-bucket.s3.amazonaws.com

# Logto
EXPO_PUBLIC_LOGTO_ENDPOINT=https://your-tenant.logto.app
EXPO_PUBLIC_LOGTO_APP_ID=your_logto_app_id

# EAS
EXPO_PUBLIC_EAS_PROJECT_ID=your_eas_project_id

# 微信（仅 native，不需要 EXPO_PUBLIC 前缀，在 app.json 或 eas secrets 配置）
WECHAT_APP_ID=your_wechat_app_id

# Sentry
SENTRY_DSN=https://xxx@sentry.io/xxx

# Mixpanel
EXPO_PUBLIC_MIXPANEL_TOKEN=your_mixpanel_token
```

> `EXPO_PUBLIC_` 前缀的变量会被打包进客户端 bundle，其他变量仅在构建时使用。**不要把任何密钥放入 `EXPO_PUBLIC_` 变量。**

---

## 附录：后端 API 快速参考

| 功能 | 方法 | 端点 | 是否需要登录 |
|---|---|---|---|
| 获取用户资料 | GET | `/api/v1/users/profile` | ✅ |
| 更新用户资料 | PATCH | `/api/v1/users/profile` | ✅ |
| 注册推送 Token | POST | `/api/v1/users/device_tokens` | ✅ |
| 获取预签名上传 URL | POST | `/api/v1/upload/presign` | ✅ |
| 订单列表 | GET | `/api/v1/orders` | ✅ |
| 创建订单 | POST | `/api/v1/orders` | ✅ |
| 订单详情 | GET | `/api/v1/orders/:id` | ✅ |
| 取消订单 | POST | `/api/v1/orders/:id/cancel` | ✅ |
| 查看报价列表 | GET | `/api/v1/orders/:order_id/bids` | ✅ 仅消费者 |
| 创建支付 | POST | `/api/v1/payments` | ✅ |
| 查询支付状态 | GET | `/api/v1/payments/:id/status` | ✅ |
| 通知列表 | GET | `/api/v1/notifications` | ✅ |
| 标记通知已读 | PATCH | `/api/v1/notifications/mark_read` | ✅ |
| 商家入驻申请 | POST | `/api/v1/merchant/apply` | ✅ |
| 商家看板 | GET | `/api/v1/merchant/dashboard` | ✅ 仅商家 |
| 商家订单列表 | GET | `/api/v1/merchant/orders` | ✅ 仅商家 |
| 工单列表 | GET | `/api/v1/tickets` | ✅ |
| 创建工单 | POST | `/api/v1/tickets` | ✅ |
| Banner 列表 | GET | `/api/v1/banners` | ❌ 公开 |
| 公告列表 | GET | `/api/v1/announcements` | ❌ 公开 |
| WebSocket | WSS | `/cable?token=<jwt>` | ✅ |
