module Elasticity
  class InstrumentedClient
    INDICES_METHODS = %w(exists create delete get_settings get_mapping flush refresh get_alias get_aliases put_alias delete_alias exists_alias update_aliases)
    INDEX_METHODS   = %w(index delete get mget search count msearch scroll delete_by_query bulk)

    def initialize(client)
      @client = client
    end

    def versions
      (@client.cluster.stats["nodes"] && @client.cluster.stats["nodes"]["versions"]) || []
    end

    # Generate wrapper methods for @client.indices
    INDICES_METHODS.each do |method_name|
      full_name = "index_#{method_name}"

      define_method(full_name) do |*args, &block|
        instrument(full_name, args) do
          @client.indices.public_send(method_name, *args, &block)
        end
      end
    end

    # Generate wrapper methods for @client
    INDEX_METHODS.each do |method_name|
      define_method(method_name) do |*args, &block|
        instrument(method_name, args) do
          @client.public_send(method_name, *args, &block)
        end
      end
    end

    private

    def instrument(name, args)
      ActiveSupport::Notifications.instrument("#{name}.elasticity", args: args, backtrace: caller(1)) do
        yield
      end
    end
  end
end
