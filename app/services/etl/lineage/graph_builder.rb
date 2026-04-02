module Etl
  module Lineage
    class GraphBuilder
      # Auto-generate lineage graph from ETL pipeline config
      GRAPH_DEFINITION = [
        # Source nodes
        { type: 'source_table', name: 'orders',            schema: 'public', desc: '订单源表' },
        { type: 'source_table', name: 'payments',          schema: 'public', desc: '支付源表' },
        { type: 'source_table', name: 'refunds',           schema: 'public', desc: '退款源表' },
        { type: 'source_table', name: 'users',             schema: 'public', desc: '用户源表' },
        { type: 'source_table', name: 'merchant_profiles', schema: 'public', desc: '商家源表' },
        { type: 'source_table', name: 'settlements',       schema: 'public', desc: '结算源表' },
        { type: 'source_table', name: 'coupons',           schema: 'public', desc: '优惠券源表' },
        # Fact/Dim nodes
        { type: 'fact_table',   name: 'dw_fact_orders',      schema: 'dw', desc: '订单事实表' },
        { type: 'fact_table',   name: 'dw_fact_payments',    schema: 'dw', desc: '支付事实表' },
        { type: 'fact_table',   name: 'dw_fact_refunds',     schema: 'dw', desc: '退款事实表' },
        { type: 'fact_table',   name: 'dw_fact_settlements', schema: 'dw', desc: '结算事实表' },
        { type: 'fact_table',   name: 'dw_fact_coupons',     schema: 'dw', desc: '优惠券事实表' },
        { type: 'dim_table',    name: 'dw_dim_users',        schema: 'dw', desc: '用户维度表/画像' },
        { type: 'dim_table',    name: 'dw_dim_merchants',    schema: 'dw', desc: '商家维度表/画像' },
        # Metric nodes
        { type: 'metric', name: 'GMV',         desc: 'GMV 成交总额指标' },
        { type: 'metric', name: 'RFM分层',     desc: '用户RFM分层标签' },
        { type: 'metric', name: '支付成功率',  desc: '支付成功率指标' },
        { type: 'metric', name: '商家评分',    desc: '商家综合评分' }
      ].freeze

      EDGES_DEFINITION = [
        # ETL edges
        { from: ['source_table', 'orders'],            to: ['fact_table', 'dw_fact_orders'],      type: 'etl' },
        { from: ['source_table', 'payments'],          to: ['fact_table', 'dw_fact_payments'],    type: 'etl' },
        { from: ['source_table', 'refunds'],           to: ['fact_table', 'dw_fact_refunds'],     type: 'etl' },
        { from: ['source_table', 'settlements'],       to: ['fact_table', 'dw_fact_settlements'], type: 'etl' },
        { from: ['source_table', 'coupons'],           to: ['fact_table', 'dw_fact_coupons'],     type: 'etl' },
        { from: ['source_table', 'users'],             to: ['dim_table', 'dw_dim_users'],         type: 'etl' },
        { from: ['source_table', 'merchant_profiles'], to: ['dim_table', 'dw_dim_merchants'],     type: 'etl' },
        # Aggregate edges
        { from: ['fact_table', 'dw_fact_orders'],    to: ['metric', 'GMV'],        type: 'aggregate', logic: 'SUM(total_amount)' },
        { from: ['dim_table', 'dw_dim_users'],       to: ['metric', 'RFM分层'],   type: 'derive',    logic: 'RFM Calculator' },
        { from: ['fact_table', 'dw_fact_payments'],  to: ['metric', '支付成功率'], type: 'aggregate', logic: 'paid/total' },
        { from: ['dim_table', 'dw_dim_merchants'],   to: ['metric', '商家评分'],   type: 'derive',    logic: 'MerchantScorer' }
      ].freeze

      def self.build!
        new.build!
      end

      def build!
        ActiveRecord::Base.transaction do
          nodes = build_nodes
          build_edges(nodes)
        end
      end

      private

      def build_nodes
        GRAPH_DEFINITION.each_with_object({}) do |defn, map|
          node = EtlLineageNode.find_or_create_by!(node_type: defn[:type], name: defn[:name]) do |n|
            n.schema_name = defn[:schema]
            n.description = defn[:desc]
          end
          map[[defn[:type], defn[:name]]] = node
        end
      end

      def build_edges(nodes)
        EDGES_DEFINITION.each do |defn|
          upstream   = nodes[defn[:from]]
          downstream = nodes[defn[:to]]
          next unless upstream && downstream

          EtlLineageEdge.find_or_create_by!(upstream: upstream, downstream: downstream) do |e|
            e.edge_type        = defn[:type]
            e.transform_logic  = defn[:logic]
          end
        end
      end
    end
  end
end
