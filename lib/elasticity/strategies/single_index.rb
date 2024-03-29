module Elasticity
  module Strategies
    class SingleIndex
      STATUSES = [:missing, :ok]

      def initialize(client, index_name, document_type, use_new_timestamp_format = nil, include_type_name_on_create = nil)
        @client        = client
        @index_name    = index_name
        @document_type = document_type
      end

      def ref_index_name
        @index_name
      end

      def remap!
        raise NotImplementedError
      end

      def missing?
        not @client.index_exists(index: @index_name)
      end

      def create(index_def)
        if missing?
          @client.index_create(index: @index_name, body: index_def)
        else
          raise IndexError.new(@index_name, "index already exist")
        end
      end

      def create_if_undefined(index_def)
        create(index_def) if missing?
      end

      def delete
        @client.index_delete(index: @index_name)
      end

      def delete_if_defined
        delete unless missing?
      end

      def recreate(index_def)
        delete_if_defined
        create(index_def)
      end

      def index_document(id, attributes)
        res = @client.index(index: @index_name, id: id, body: attributes)

        if id = res["_id"]
          [id, res["created"]]
        else
          raise IndexError.new(@update_alias, "failed to index document. Response: #{res.inspect}")
        end
      end

      def delete_document(id)
        @client.delete(index: @index_name, id: id)
      end

      def get_document(id)
        @client.get(index: @index_name, id: id)
      end

      def search_index
        @index_name
      end

      def delete_by_query(body)
        @client.delete_by_query(index: @index_name, body: body)
      end

      def bulk
        b = Bulk::Index.new(@client, @index_name)
        yield b
        b.execute
      end

      def settings
        @client.index_get_settings(index: @index_name).values.first
      rescue Elastic::Transport::Transport::Errors::NotFound
        nil
      end

      def mappings
        ActiveSupport::Deprecation.warn(
          "Elasticity::Strategies::SingleIndex#mappings is deprecated, "\
          "use mapping instead"
        )
        mapping
      end

      def mapping
        @client.index_get_mapping(index: @index_name).values.first
      rescue Elastic::Transport::Transport::Errors::NotFound
        nil
      end

      def flush
        @client.index_flush(index: @index_name)
      end

      def refresh
        @client.index_refresh(index: @index_name)
      end
    end
  end
end
