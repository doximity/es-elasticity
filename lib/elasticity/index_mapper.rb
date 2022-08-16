module Elasticity
  class IndexMapper
    def self.set_delegates(obj, to)
      obj.delegate(
        :document_type,
        :mapping,
        :ref_index_name,
        :create_index,
        :recreate_index,
        :delete_index,
        :index_exists?,
        :remap!,
        :flush_index,
        :refresh_index,
        :index_document,
        :search,
        :get,
        :delete,
        :delete_by_search,
        :bulk_index,
        :bulk_update,
        :bulk_delete,
        :map_hit,
        to: to
      )
    end

    def initialize(document_klass, index_config)
      @document_klass = document_klass
      @index_config   = index_config
      @strategy       = @index_config.strategy.new(@index_config.client, @index_config.fq_index_base_name, @index_config.document_type, @index_config.use_new_timestamp_format, @index_config.include_type_name_on_create)
    end

    delegate(
      :document_type,
      :document_types,
      :mapping,
      :ref_index_name,
      to: :@index_config
    )

    # Creates the index for this document
    def create_index
      @strategy.create_if_undefined(@index_config.definition)
    end

    # Re-creates the index for this document
    def recreate_index
      @strategy.recreate(@index_config.definition)
    end

    # Deletes the index
    def delete_index
      @strategy.delete
    end

    # Does the index exist?
    def index_exists?
      !@strategy.missing?
    end

    # Gets the index name to be used when you need to reference the index somewhere.
    # This depends on the @strategy being used, but it always refers to the search index.
    def ref_index_name
      @strategy.ref_index_name
    end

    # Remap
    # retry_delay & max_delay are in seconds
    def remap!(retry_delete_on_recoverable_errors: true, retry_delay: 30, max_delay: 600)
      @strategy.remap(@index_config.definition, retry_delete_on_recoverable_errors: retry_delete_on_recoverable_errors, retry_delay: retry_delay, max_delay: max_delay)
    end

    # Flushes the index, forcing any writes
    # note that v7 no longer forces any writes on flush
    def flush_index
      @strategy.flush
    end

    # Resfreshes the index, forcing any writes
    def refresh_index
      @strategy.refresh
    end

    # Index the given document
    def index_document(id, document_hash)
      @strategy.index_document(id, document_hash)
    end

    # Searches the index using the parameters provided in the body hash, following the same
    # structure Elasticsearch expects.
    # Returns a DocumentSearch object.
    # search_args allows for
    #   explain: boolean to specify we should request _explanation of the query
    def search(body, search_args = {})
      search_obj = Search.build(@index_config.client, @strategy.search_index, document_types, body, search_args)
      Search::DocumentProxy.new(search_obj, self.method(:map_hit))
    end

    # Fetches one specific document from the index by ID.
    def get(id)
      doc = @strategy.get_document(id)
      @document_klass.new(doc["_source"].merge(_id: doc["_id"])) if doc.present?
    end

    # Removes one specific document from the index.
    def delete(id)
      @strategy.delete_document(id)
    end

    # Removes entries based on a search
    def delete_by_search(search)
      @strategy.delete_by_query(search.body)
    end

    # Bulk index the provided documents
    def bulk_index(documents)
      @strategy.bulk do |b|
        documents.each do |doc|
          b.index(doc._id, doc.to_document)
        end
      end
    end

    # Bulk update the specicied attribute of the provided documents
    def bulk_update(documents)
      @strategy.bulk do |b|
        documents.each do |doc|
          b.update(
            doc[:_id],
            { doc: { doc[:attr_name] => doc[:attr_value] } }
          )
        end
      end
    end

    # Bulk delete documents matching provided ids
    def bulk_delete(ids)
      @strategy.bulk do |b|
        ids.each do |id|
          b.delete(id)
        end
      end
    end

    # Creates a instance of a document from a ElasticSearch hit data.
    def map_hit(hit)
      attrs = { _id: hit["_id"] }
      attrs.merge!(_score: hit["_score"])
      attrs.merge!(sort: hit["sort"])
      attrs.merge!(hit["_source"]) if hit["_source"]
      attrs.merge!(matched_queries: hit["matched_queries"]) if hit["matched_queries"]

      highlighted = nil

      if hit["highlight"]
        highlighted_attrs = hit["highlight"].each_with_object({}) do |(name, v), attrs|
          name = name.gsub(/\..*\z/, "")

          attrs[name] ||= v
        end

        highlighted = @document_klass.new(attrs.merge(highlighted_attrs))
      end

      injected_attrs = attrs.merge({
        highlighted: highlighted,
        highlighted_attrs: highlighted_attrs.try(:keys),
        _explanation: hit["_explanation"]
      })

      if @document_klass.config.subclasses.present?
        @document_klass.config.subclasses[hit["_type"].to_sym].constantize.new(injected_attrs)
      else
        @document_klass.new(injected_attrs)
      end
    end
  end
end
