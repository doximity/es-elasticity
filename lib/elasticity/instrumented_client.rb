module Elasticity
  class InstrumentedClient
    def initialize(client)
      @client = client
    end

    # Generate wrapper methods for @client.indices
    %w(exists create delete get_settings get_mapping flush).each do |method_name|
      full_name = "index_#{method_name}"

      define_method(full_name) do |*args, &block|
        instrument(full_name, args) do
          @client.indices.public_send(method_name, *args, &block)
        end
      end
    end

    # Generate wrapper methods for @client
    %w(index delete get search delete_by_query bulk).each do |method_name|
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
