module Elasticity
  module Strategies
    class AliasIndex
      STATUSES = [:missing, :ok]

      def initialize(client, index_base_name)
        @client       = client
        @main_alias   = index_base_name
        @update_alias = "#{@index_base_name}_update"
      end

      def remap(index_def)
        main_indexes   = self.main_indexes
        update_indexes = self.update_indexes

        if main_indexes.size != 1 || update_indexes.size != 1 || main_indexes != update_indexes
          raise "Index can't be remapped right now, check if another remapping is already happening"
        end

        new_update_index = create_index(index_def)
        old_update_index = update_indexes[0]
        old_main_index   = main_indexes[0]

        @client.index_update_aliases(body: {
          actions: [
            { remove: { index: old_update_index, alias: @update_alias } },
            { add:    { index: new_update_index, alias: @update_alias } },
            { add:    { index: new_update_index, alias: @main_alias }},
          ]
        })

        @client.index_flush(index: old_main_index)

        r = @client.search index: old_main_index, search_type: 'scan', scroll: '1m', size: 100
        loop do
          r    = @client.scroll(scroll_id: r['_scroll_id'], scroll: '1m')
          hits = r['hits']['hits']
          break if hits.empty?

          b = Bulk::Alias.new(@client, new_update_index, [old_main_index])
          hits.each do |hit|
            b.index(hit["_type"], hit["_id"], hit["_source"])
          end
          b.execute
        end

        @client.index_delete_alias(index: old_main_index, name: @main_alias)
        @client.index_delete(index: old_main_index)
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
          @client.index_put_alias(index: index_name, name: @main_alias)
          @client.index_put_alias(index: index_name, name: @update_alias)
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
        deleted = false

        main_indexes.each do |index|
          begin
            @client.delete(index: index, type: type, id: id)
            deleted = true
          rescue Elasticsearch::Transport::Transport::Errors::NotFound
          end
        end

        update_indexes.each do |index|
          begin
            @client.delete(index: index, type: type, id: id)
            deleted = true
          rescue Elasticsearch::Transport::Transport::Errors::NotFound
          end
        end

        deleted
      end

      def get_document(type, id)
        @client.get(index: @main_alias, type: type, id: id)
      end

      def search(type, body)
        Search.new(@client, @main_alias, type, body)
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
