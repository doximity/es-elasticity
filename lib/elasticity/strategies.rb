# frozen_string_literal: true

module Elasticity
  module Strategies
    class IndexError < StandardError
      attr_reader :index_base_name

      def initialize(index_base_name, message)
        @index_base_name = index_base_name
        super("#{index_base_name}: #{message}")
      end
    end

    autoload :SingleIndex, "elasticity/strategies/single_index"
    autoload :AliasIndex,  "elasticity/strategies/alias_index"
  end
end
