module Elasticity
  module Strategies
    class IndexError < StandardError
      attr_reader :index_base_name

      def initialize(index_base_name, message)
        @index_name = index_name
        super("#{index_name}: #{message}")
      end
    end

    autoload :SingleIndex, "elasticity/strategies/single_index"
    autoload :AliasIndex,  "elasticity/strategies/alias_index"
  end
end
