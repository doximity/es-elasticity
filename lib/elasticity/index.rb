module Elasticity
  class Index
    attr_reader :name

    def initialize(client, index_name, index_def)
      @client    = client
      @name      = index_name
      @index_def = index_def
    end

    def create
      args = { index: @name, body: @index_def }
      instrument("index_create", args) { @client.indices.create(args) }
    end

    def create_if_undefined
      create unless @client.indices.exists(index: @name)
    end

    def delete
      args = { index: @name }
      instrument("index_delete", args) { @client.indices.delete(args) }
    end

    def recreate
      delete if @client.indices.exists(index: @name)
      create
    end

    def add_document(type, id, attributes)
      create_if_undefined

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

    private

    def instrument(name, extra = {})
      ActiveSupport::Notifications.instrument("elasticity.#{name}", extra) do
        yield
      end
    end
  end
end
