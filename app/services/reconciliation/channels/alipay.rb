module Reconciliation
  module Channels
    class Alipay < Base
      def parse
        # TODO: 支付宝账单解析存根 (Stub)
        # 注意：由于目前支付宝支付接口凭证尚在申请中，因此暂时留白。
        # 当资质申请通过后：
        # 1. 配置 Alipay API SDK
        # 2. 定时任务每日调用 API 下载账单
        # 3. 在这里将账单解析为标准对账格式返回
        raise NotImplementedError, "支付宝流水对账功能暂未开放（凭证申请中）"
      end
    end
  end
end
