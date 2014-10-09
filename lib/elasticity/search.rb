module Elasticity
  # Search provides a simple interface for defining a search against an ElasticSearch
  # index and fetching the results in different ways and mappings.
  #
  # Example:
  #   search = Elasticity::Search.new("people", "person", {...})
  #   search.documents(Person)
  class Search
    attr_reader :index, :document_type, :body

    # Creates a new Search definitions for the given index, document_type and criteria. The
    # search is not performend until methods are called, each method represents a different
    # way of fetching and mapping the data.
    #
    # The body parameter is a hash following the exact same syntax as ElasticSearch's JSON
    # query language.
    def initialize(index, document_type, body)
      @index          = index
      @document_type  = document_type.freeze
      @body           = body.freeze
    end

    # Execute the search, fetching only ids from ElasticSearch and then mapping the results
    # into ActiveRecord models using the provided relation.
    def active_records(relation)
      return @active_record if defined?(@active_record)
      response = @index.search(@document_type, @body.merge(_source: false))
      @active_record = Result.new(response, ActiveRecordMapper.new(relation))
    end

    # Execute the search, fetching all documents from the index and mapping the stored attributes
    # into instances of the provided class. It will call document_klass.new(attrs), where attrs
    # are the stored attributes.
    def documents(document_klass)
      return @documents if defined?(@documents)
      response = @index.search(@document_type, @body)
      @documents = Result.new(response, DocumentMapper.new(document_klass))
    end

    # Result is a collection representing the response from a search against an index. It's what gets
    # returned by any of the Elasticity::Search methods and it provides a lazily-evaluated and
    # lazily-mapped – using the provided mapper class.
    #
    # Example:
    #
    #   response = {"took"=>0, "timed_out"=>false, "_shards"=>{"total"=>5, "successful"=>5, "failed"=>0}, "hits"=>{"total"=>2, "max_score"=>1.0, "hits"=>[
    #     {"_index"=>"my_index", "_type"=>"my_type", "_id"=>"1", "_score"=>1.0, "_source"=> { "id" => 1, "name" => "Foo" },
    #     {"_index"=>"my_index", "_type"=>"my_type", "_id"=>"2", "_score"=>1.0, "_source"=> { "id" => 2, "name" => "Bar" },
    #   ]}}
    #
    #   class AttributesMapper
    #     def map(hits)
    #       hits.map { |h| h["_source"] }
    #     end
    #   end
    #
    #   r = Result.new(response, AttributesMapper.new)
    #   r.total # => 2
    #   r[0]    # => { "id" => 1, "name" => "Foo" }
    #
    class Result
      include Enumerable

      def initialize(response, mapper)
        @response = response
        @mapper   = mapper
      end

      delegate :[], :each, :to_ary, :size, :+, :-, to: :mapping

      # The total number of entries as returned by ES
      def total
        @response["hits"]["total"]
      end

      def empty?
        total == 0
      end

      def blank?
        empty?
      end

      def suggestions
        @response["suggest"] || {}
      end

      def mapping
        return @mapping if defined?(@mapping)
        hits = Array(@response["hits"]["hits"])
        @mapping = @mapper.map(hits)
      end
    end

    class DocumentMapper
      def initialize(document_klass)
        @document_klass = document_klass
      end

      def map(hits)
        hits.map do |hit|
          @document_klass.new(hit["_source"].merge(_id: hit['_id']))
        end
      end
    end

    class ActiveRecordMapper
      def initialize(relation)
        @relation = relation
      end

      def map(hits)
        ids = hits.map { |h| h["_id"] }

        if ids.any?
          id_col = "#{quote(@relation.table_name)}.#{quote(@relation.klass.primary_key)}"
          @relation.where(id: ids).order("FIELD(#{id_col},#{ids.join(',')})")
        else
          @relation.none
        end
      end

      private

      def quote(identifier)
        @relation.connection.quote_column_name(identifier)
      end
    end
  end

  class DocumentSearchProxy < BasicObject
    def initialize(search, document_klass)
      @search         = search
      @document_klass = document_klass
    end

    def index
      @search.index
    end

    def document_type
      @search.document_type
    end

    def body
      @search.body
    end

    def active_records(relation)
      @search.active_records(relation)
    end

    def documents
      @search.documents(@document_klass)
    end

    def method_missing(method_name, *args, &block)
      documents.public_send(method_name, *args, &block)
    end
  end
end
