module Elasticity
  class Index
    attr_reader :name

    def initialize(client, index_name)
      @client    = client
      @name      = index_name
    end

    def create(index_def)
      args = { index: @name, body: index_def }
      instrument("index_create", args) { @client.indices.create(args) }
    end

    def create_if_undefined(index_def)
      create(index_def) unless @client.indices.exists(index: @name)
    end

    def delete
      args = { index: @name }
      instrument("index_delete", args) { @client.indices.delete(args) }
    end

    def delete_if_defined
      delete if @client.indices.exists(index: @name)
    end

    def recreate(index_def = nil)
      index_def ||= { settings: settings, mappings: mappings }
      delete_if_defined
      create(index_def)
    end

    def index_document(type, id, attributes)
      args = { index: @name, type: type, id: id, body: attributes }
      instrument("index_document", args) { @client.index(args) }
    end

    def delete_document(type, id)
      args = { index: @name, type: type, id: id }
      instrument("delete_document", args) { @client.delete(args) }
    end

    def get_document(type, id)
      args = { index: @name, type: type, id: id }
      instrument("get_document", args) { @client.get(args) }
    end

    def search(type, body)
      args = { index: @name, type: type, body: body }
      instrument("search", args) { @client.search(args) }
    end

    def delete_by_query(type, body)
      args = { index: @name, type: type, body: body }
      instrument("delete_by_query", args) { @client.delete_by_query(args) }
    end

    def bulk
      b = Bulk.new(@client, @name)
      yield b
      b.execute
    end

    def settings
      args = { index: @name }
      settings = instrument("settings", args) { @client.indices.get_settings(args) }
      settings[@name]["settings"] if settings[@name]
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      nil
    end

    def mappings
      args = { index: @name }
      mappings = instrument("mappings", args) { @client.indices.get_mapping(args) }
      mappings[@name]["mappings"] if mappings[@name]
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      nil
    end

    def flush
      args = { index: @name }
      instrument("flush", args) { @client.indices.flush(args) }
    end

    private

    def instrument(name, extra = {})
      ActiveSupport::Notifications.instrument("elasticity.#{name}", args: extra) do
        yield
      end
    end

    class Bulk
      def initialize(client, name)
        @client     = client
        @name       = name
        @operations = []
      end

      def index(type, id, attributes)
        @operations << { index: { _index: @name, _type: type, _id: id, data: attributes }}
      end

      def delete(type, id)
        @operations << { delete: { _index: @name, _type: type, _id: id }}
      end

      def execute
        @client.bulk(body: @operations)
      end
    end
  end
end
