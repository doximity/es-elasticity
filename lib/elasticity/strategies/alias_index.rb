module Elasticity
  module Strategies
    # This strategy keeps two aliases that might be mapped to the same index or different index, allowing
    # runtime changes by simply atomically updating the aliases. For example, look at the remap method
    # implementation.
    class AliasIndex
      STATUSES = [:missing, :ok]

      def initialize(client, index_base_name)
        @client       = client
        @main_alias   = index_base_name
        @update_alias = "#{index_base_name}_update"
      end

      def ref_index_name
        @main_alias
      end

      # Remap allows zero-downtime/zero-dataloss remap of elasticsearch indexes. Here is the overview
      # of how it works:
      #
      # 1. Creates a new index with the new mapping
      # 2. Update the aliases so that any write goes to the new index and reads goes to both indexes.
      # 3. Use scan and scroll to iterate over all the documents in the old index, moving them to the
      #    new index.
      # 4. Update the aliases so that all operations goes to the new index.
      # 5. Deletes the old index.
      #
      # It does a little bit more to ensure consistency and to handle race-conditions. For more details
      # look at the implementation.
      def remap(index_def)
        main_indexes   = self.main_indexes
        update_indexes = self.update_indexes

        if main_indexes.size != 1 || update_indexes.size != 1 || main_indexes != update_indexes
          raise "Index can't be remapped right now, check if another remapping is already happening"
        end

        new_index      = create_index(index_def)
        original_index = main_indexes[0]

        begin
          # Configure aliases so that search includes the old index and the new index, and writes are made to
          # the new index.
          @client.index_update_aliases(body: {
            actions: [
              { remove: { index: original_index, alias: @update_alias } },
              { add:    { index: new_index, alias: @update_alias } },
              { add:    { index: new_index, alias: @main_alias }},
            ]
          })

          @client.index_flush(index: original_index)
          cursor = @client.search index: original_index, search_type: 'scan', scroll: '10m', _source: false, size: 100
          loop do
            cursor = @client.scroll(scroll_id: cursor['_scroll_id'], scroll: '1m')
            hits   = cursor['hits']['hits']
            break if hits.empty?

            # Fetch documents based on the ids that existed when the migration started, to make sure we only migrate
            # documents that haven't been deleted.
            id_docs = hits.map do |hit|
              { _index: original_index, _type: hit["_type"], _id: hit["_id"] }
            end

            docs = @client.mget(body: { docs: id_docs }, refresh: true)["docs"]
            break if docs.empty?

            # Move only documents that still exists on the old index, into the new index.
            ops = []
            docs.each do |doc|
              ops << { index: { _index: new_index, _type: doc["_type"], _id: doc["_id"], data: doc["_source"] } } if doc["found"]
            end

            @client.bulk(body: ops)

            # Deal with race conditions by removing from the new index any document that doesn't exist in the old index anymore.
            ops = []
            @client.mget(body: { docs: id_docs }, refresh: true)["docs"].each_with_index do |new_doc, idx|
              if docs[idx]["found"] && !new_doc["found"]
                ops << { delete: { _index: new_index, _type: new_doc["_type"], _id: new_doc["_id"] } }
              end
            end

            @client.bulk(body: ops) unless ops.empty?
          end

          # Update aliases to only point to the new index.
          @client.index_update_aliases(body: {
            actions: [
              { remove: { index: original_index, alias: @main_alias } },
            ]
          })
          @client.index_delete(index: original_index)

        rescue
          @client.index_update_aliases(body: {
            actions: [
              { add:    { index: original_index, alias: @update_alias } },
              { remove: { index: new_index, alias: @update_alias } },
            ]
          })

          @client.index_flush(index: new_index)
          cursor = @client.search index: new_index, search_type: 'scan', scroll: '1m', size: 100
          loop do
            cursor = @client.scroll(scroll_id: cursor['_scroll_id'], scroll: '1m')
            hits   = cursor['hits']['hits']
            break if hits.empty?

            # Move all the documents that exists on the new index back to the old index
            ops = []
            hits.each do |doc|
              ops << { index: { _index: original_index, _type: doc["_type"], _id: doc["_id"], data: doc["_source"] } }
            end

            @client.bulk(body: ops)
          end

          @client.index_flush(index: original_index)
          @client.index_update_aliases(body: {
            actions: [
              { remove: { index: new_index, alias: @main_alias } },
            ]
          })
          @client.index_delete(index: new_index)

          raise
        end
      end

      def status
        search_exists = @client.index_exists_alias(name: @main_alias)
        update_exists = @client.index_exists_alias(name: @update_alias)

        case
        when search_exists && update_exists
          :ok
        when !search_exists && !update_exists
          :missing
        else
          :inconsistent
        end
      end

      def missing?
        status == :missing
      end

      def main_indexes
        @client.index_get_aliases(index: "#{@main_alias}-*", name: @main_alias).keys
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        []
      end

      def update_indexes
        @client.index_get_aliases(index: "#{@main_alias}-*", name: @update_alias).keys
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        []
      end

      def create(index_def)
        if missing?
          index_name = create_index(index_def)
          @client.index_update_aliases(body: {
            actions: [
              { add: { index: index_name, alias: @main_alias } },
              { add: { index: index_name, alias: @update_alias } },
            ]
          })
        else
          raise IndexError.new(@main_alias, "index already exists")
        end
      end

      def create_if_undefined(index_def)
        create(index_def) if missing?
      end

      def delete
        @client.index_delete(index: "#{@main_alias}-*")
      end

      def delete_if_defined
        delete unless missing?
      end

      def recreate(index_def)
        delete_if_defined
        create(index_def)
      end

      def index_document(type, id, attributes)
        res = @client.index(index: @update_alias, type: type, id: id, body: attributes)

        if id = res["_id"]
          [id, res["created"]]
        else
          raise IndexError.new(@update_alias, "failed to index document")
        end
      end

      def delete_document(type, id)
        ops = (main_indexes | update_indexes).map do |index|
          { delete: { _index: index, _type: type, _id: id } }
        end

        @client.bulk(body: ops)
      end

      def get_document(type, id)
        @client.get(index: @main_alias, type: type, id: id)
      end

      def search(type, body)
        Search::Facade.new(@client, Search::Definition.new(@main_alias, type, body))
      end

      def delete_by_query(type, body)
        @client.delete_by_query(index: @main_alias, type: type, body: body)
      end

      def bulk
        b = Bulk::Alias.new(@client, @update_alias, main_indexes)
        yield b
        b.execute
      end

      def flush
        @client.index_flush(index: @update_alias)
      end

      def settings
        args = { index: @main_alias }
        settings = @client.index_get_settings(index: @main_alias)
        settings[@main_alias]["settings"]
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end

      def mappings
        args = { index: @main_alias }
        mapping = @client.index_get_mapping(index: @main_alias)
        mapping[@main_alias]["mappings"]
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end

      private

      def create_index(index_def)
        ts = Time.now.utc.strftime("%Y-%m-%d_%H:%M:%S.%6N")
        index_name = "#{@main_alias}-#{ts}"
        @client.index_create(index: index_name, body: index_def)
        index_name
      end
    end
  end
end
