module Etl
  module Lineage
    class GraphSerializer
      # Returns Mermaid.js flowchart definition string
      def self.to_mermaid
        new.to_mermaid
      end

      def to_mermaid
        nodes = EtlLineageNode.active.includes(:outgoing_edges).to_a
        edges = EtlLineageEdge.includes(:upstream, :downstream).to_a

        lines = ["flowchart LR"]

        # Node definitions with styling
        nodes.each do |node|
          label = "#{node.name}\\n[#{node.node_type}]"
          lines << "  #{node_id(node)}[\"#{label}\"]"
        end

        # Style classes
        lines << "  classDef source fill:#f9f,stroke:#333"
        lines << "  classDef fact fill:#bbf,stroke:#333"
        lines << "  classDef dim fill:#bfb,stroke:#333"
        lines << "  classDef metric fill:#ff9,stroke:#333"

        # Apply classes
        nodes.group_by(&:node_type).each do |type, type_nodes|
          css_class = type_to_class(type)
          next unless css_class
          ids = type_nodes.map { |n| node_id(n) }.join(',')
          lines << "  class #{ids} #{css_class}"
        end

        # Edge definitions
        edges.each do |edge|
          next unless edge.upstream && edge.downstream
          label = edge.transform_logic.present? ? "|#{edge.transform_logic}|" : ""
          arrow = edge.edge_type == 'etl' ? "-->" : "-.->"
          lines << "  #{node_id(edge.upstream)} #{arrow}#{label} #{node_id(edge.downstream)}"
        end

        lines.join("\n")
      end

      # Returns JSON suitable for D3.js / vis.js
      def self.to_json_graph
        nodes = EtlLineageNode.active.map do |n|
          { id: n.id, label: n.name, type: n.node_type, description: n.description }
        end
        edges = EtlLineageEdge.includes(:upstream, :downstream).map do |e|
          { from: e.upstream_id, to: e.downstream_id, type: e.edge_type, label: e.transform_logic }
        end
        { nodes: nodes, edges: edges }
      end

      private

      def node_id(node)
        "N#{node.id}"
      end

      def type_to_class(type)
        {
          'source_table' => 'source',
          'fact_table'   => 'fact',
          'dim_table'    => 'dim',
          'metric'       => 'metric'
        }[type]
      end
    end
  end
end
