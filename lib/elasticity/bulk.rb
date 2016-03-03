module Elasticity
  class Bulk
    def initialize(client)
      @client     = client
      @operations = []
    end

    def index(index_name, type, id, attributes)
      @operations << { index: { _index: index_name, _type: type, _id: id, data: attributes }}
    end

    def update(index_name, type, id, attributes)
      @operations << { update: { _index: index_name, _type: type, _id: id, data: attributes }}
    end

    def delete(index_name, type, id)
      @operations << { delete: { _index: index_name, _type: type, _id: id }}
    end

    def execute
      @client.bulk(body: @operations)
    end

    class Index < Bulk
      def initialize(client, index_name)
        super(client)
        @index_name = index_name
      end

      def index(type, id, attributes)
        super(@index_name, type, id, attributes)
      end

      def update(type, id, attributes)
        super(@index_name, type, id, attributes)
      end

      def delete(type, id)
        super(@index_name, type, id)
      end
    end

    class Alias < Bulk
      def initialize(client, update_alias, delete_indexes)
        super(client)
        @update_alias   = update_alias
        @delete_indexes = delete_indexes
      end

      def index(type, id, attributes)
        super(@update_alias, type, id, attributes)
      end

      def update(type, id, attributes)
        super(@update_alias, type, id, attributes)
      end

      def delete(type, id)
        @delete_indexes.each do |index|
          super(index, type, id)
        end
      end
    end
  end
end
