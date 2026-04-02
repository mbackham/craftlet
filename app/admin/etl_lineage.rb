# frozen_string_literal: true

ActiveAdmin.register_page "EtlLineage" do
  menu parent: "etl_menu", priority: 6,
       label: proc { I18n.t("admin.etl.menu.lineage", default: "血缘关系图") }

  content title: proc { I18n.t("admin.etl.lineage.title", default: "数据血缘关系图") } do
    # Auto-build lineage if nodes are empty
    Etl::Lineage::GraphBuilder.build! if EtlLineageNode.count.zero?

    mermaid_code = Etl::Lineage::GraphSerializer.to_mermaid

    # Mermaid visualization
    panel I18n.t("admin.etl.lineage.graph", default: "血缘图 (Mermaid)") do
      div style: "padding: 10px;" do
        # Mermaid.js render container
        div class: "mermaid", style: "background: white; padding: 20px; border-radius: 4px;" do
          text_node mermaid_code
        end

        # Include Mermaid.js via CDN
        javascript_tag do
          raw <<~JS
            (function() {
              var script = document.createElement('script');
              script.src = 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js';
              script.onload = function() { mermaid.initialize({ startOnLoad: true, theme: 'default' }); };
              document.head.appendChild(script);
            })();
          JS
        end
      end
    end

    # Mermaid source code for copy
    panel I18n.t("admin.etl.lineage.source", default: "血缘图源码 (Mermaid)") do
      pre mermaid_code
    end

    columns do
      # Node list
      column do
        panel I18n.t("admin.etl.lineage.nodes", default: "数据节点") do
          table_for EtlLineageNode.active.order(:node_type, :name) do
            column I18n.t("admin.etl.lineage.node_type", default: "类型"), :node_type
            column I18n.t("admin.etl.lineage.node_name", default: "名称"), :name
            column :description
            column I18n.t("admin.etl.lineage.downstream_count", default: "下游节点数") do |node|
              node.outgoing_edges.count
            end
          end
        end
      end

      # Edge list
      column do
        panel I18n.t("admin.etl.lineage.edges", default: "数据流向") do
          table_for EtlLineageEdge.includes(:upstream, :downstream).all do
            column I18n.t("admin.etl.lineage.upstream", default: "上游") do |edge|
              edge.upstream&.name
            end
            column "→"
            column I18n.t("admin.etl.lineage.downstream", default: "下游") do |edge|
              edge.downstream&.name
            end
            column :edge_type
            column :transform_logic
          end
        end
      end
    end

    # Rebuild action
    panel I18n.t("admin.etl.lineage.management", default: "血缘图管理") do
      div style: "display: flex; gap: 10px;" do
        link_to I18n.t("admin.etl.actions.rebuild_lineage", default: "重新构建血缘图"),
                admin_etllineage_rebuild_path,
                method: :post,
                class: "button",
                data: { confirm: I18n.t("admin.etl.confirm.rebuild_lineage", default: "将重新生成所有血缘节点和边，确认？") }
      end
    end
  end

  page_action :rebuild, method: :post do
    Etl::Lineage::GraphBuilder.build!
    redirect_to admin_etllineage_path, notice: I18n.t("admin.etl.notices.lineage_rebuilt", default: "血缘图已重建")
  end
end
