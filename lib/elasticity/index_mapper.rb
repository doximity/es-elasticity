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
      @strategy       = @index_config.strategy.new(@index_config.client, @index_config.fq_index_base_name, @index_config.document_type)
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
      @index_config.check_subclass_exception
      @strategy.create_if_undefined(@index_config.definition)
    end

    # Re-creates the index for this document
    def recreate_index
      @index_config.check_subclass_exception
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
    def remap!
      @strategy.remap(@index_config.definition)
    end

    # Flushes the index, forcing any writes
    def flush_index
      @strategy.flush
    end

    # Index the given document
    def index_document(id, document_hash)
      @index_config.check_subclass_exception
      @strategy.index_document(document_type, id, document_hash)
    end

    # Searches the index using the parameters provided in the body hash, following the same
    # structure Elasticsearch expects.
    # Returns a DocumentSearch object.
    def search(body)
      search_obj = Search.build(@index_config.client, @strategy.search_index, document_types, body)
      Search::DocumentProxy.new(search_obj, self.method(:map_hit))
    end

    # Fetches one specific document from the index by ID.
    def get(id)
      doc = @strategy.get_document(document_type, id)
      @document_klass.new(doc["_source"].merge(_id: doc['_id'])) if doc.present?
    end

    # Removes one specific document from the index.
    def delete(id)
      @strategy.delete_document(document_type, id)
    end

    # Removes entries based on a search
    def delete_by_search(search)
      @strategy.delete_by_query(document_type, search.body)
    end

    # Bulk index the provided documents
    def bulk_index(documents)
      @strategy.bulk do |b|
        documents.each do |doc|
          b.index(document_type, doc._id, doc.to_document)
        end
      end
    end

    # Bulk update the specicied attribute of the provided documents
    def bulk_update(documents)
      @strategy.bulk do |b|
        documents.each do |doc|
          b.update(
            document_type,
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
          b.delete(document_type, id)
        end
      end
    end

    # Creates a instance of a document from a ElasticSearch hit data.
    def map_hit(hit)
      attrs = { _id: hit["_id"] }
      attrs.merge!(_score: hit["_score"])
      attrs.merge!(sort: hit["sort"])
      attrs.merge!(hit["_source"]) if hit["_source"]

      if hit["highlight"]
        highlighted_attrs = attrs.dup
        attrs_set = Set.new

        hit["highlight"].each do |name, v|
          name = name.gsub(/\..*\z/, '')
          next if attrs_set.include?(name)
          highlighted_attrs[name] = v
          attrs_set << name
        end

        highlighted = @document_klass.new(highlighted_attrs)
      end
      if @document_klass.config.subclasses.present?
        @document_klass.config.subclasses[hit["_type"].to_sym].constantize.new(attrs.merge(highlighted: highlighted))
      else
        @document_klass.new(attrs.merge(highlighted: highlighted))
      end
    end
  end
end
