module Etl
  module Lineage
    class ImpactAnalyzer
      def initialize(node)
        @node = node
      end

      # Returns all downstream nodes (BFS)
      def downstream_impact
        visited = {}
        queue   = [@node]

        while queue.any?
          current = queue.shift
          next if visited[current.id]

          visited[current.id] = current
          current.downstream_nodes.each { |n| queue << n }
        end

        visited.values - [@node]
      end

      # Returns all upstream nodes (BFS)
      def upstream_lineage
        visited = {}
        queue   = [@node]

        while queue.any?
          current = queue.shift
          next if visited[current.id]

          visited[current.id] = current
          current.upstream_nodes.each { |n| queue << n }
        end

        visited.values - [@node]
      end
    end
  end
end
