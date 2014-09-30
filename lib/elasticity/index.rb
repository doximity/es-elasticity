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

    def add_document(type, id, attributes)
      args = { index: @name, type: type, id: id, body: attributes }
      instrument("document_index", args) { @client.index(args) }
    end

    def del_document(type, id)
      args = { index: @name, type: type, id: id }
      instrument("document_delete", args) { @client.delete(args) }
    end

    def get_document(type, id)
      args = { index: @name, type: type, id: id }
      instrument("document_get", args) { @client.get(args) }
    end

    def search(type, body)
      args = { index: @name, type: type, body: body }
      instrument("search", args) { @client.search(args) }
    end

    def settings
      args = { index: @name }
      settings = instrument("settings", args) { @client.indices.get_settings(args) }

      if settings[@name]
        settings[@name]["settings"]
      else
        {}
      end
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      nil
    end

    def mappings
      args = { index: @name }
      mappings = instrument("mappings", args) { @client.indices.get_mapping(args) }

      if mappings[@name]
        mappings[@name]["mappings"]
      else
        {}
      end
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
  end
end
