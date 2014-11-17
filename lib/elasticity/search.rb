module Elasticity
  module Search
    # Elasticity::Search::Definition is a struct that encapsulates all the data specific to one
    # ElasticSearch search.
    class Definition
      attr_accessor :index_name, :document_type, :body

      def initialize(index_name, document_type, body)
        @index_name    = index_name
        @document_type = document_type
        @body          = body
      end

      def update(body_changes)
        self.class.new(@index_name, @document_type, @body.deep_merge(body_changes))
      end

      def to_search_args
        { index: @index_name, type: @document_type, body: @body }
      end

      def to_msearch_args
        { index: @index_name, type: @document_type, search: @body }
      end
    end

    # Elasticity::Search::Facade provides a simple interface for defining a search and provides
    # different ways of executing it against Elasticsearch. This is usually the main entry point
    # for search.
    class Facade
      attr_accessor :search_definition

      # Creates a new facade for the given search definition, providing a set of helper methods
      # to trigger different type of searches and results interpretation.
      def initialize(client, search_definition)
        @client            = client
        @search_definition = search_definition
      end

      # Performs the search using the default search type and returning an iterator that will yield
      # hash representations of the documents.
      def document_hashes
        LazySearch.new(@client, @search_definition)
      end

      # Performs the search using the default search type and returning an iterator that will yield
      # each document, converted to the provided document_klass.
      def documents(document_klass)
        LazySearch.new(@client, @search_definition) do |hit|
          document_klass.from_hit(hit)
        end
      end

      # Performs the search using the scan search type and the scoll api to iterate over all the documents
      # as fast as possible. The sort option will be discarded.
      #
      # More info: http://www.elasticsearch.org/guide/en/elasticsearch/guide/current/scan-scroll.html
      def scan_documents(document_klass, **options)
        ScanCursor.new(@client, @search_definition, document_klass, **options)
      end

      # Performs the search only fetching document ids using it to load ActiveRecord objects from the provided
      # relation. It returns the relation matching the objects found on ElasticSearch.
      def active_records(relation)
        ActiveRecordProxy.new(@client, @search_definition, relation)
      end
    end

    class LazySearch
      include Enumerable

      delegate :each, :size, :length, :[], :+, :-, :&, :|, to: :search_results

      attr_accessor :search_definition

      def initialize(client, search_definition, &mapper)
        @client            = client
        @search_definition = search_definition
        @mapper            = mapper
      end

      def empty?
        total == 0
      end

      def blank?
        empty?
      end

      def total
        response["hits"]["total"]
      end

      def suggestions
        response["hits"]["suggest"] ||= {}
      end

      def search_results
        return @search_results if defined?(@search_results)

        hits = response["hits"]["hits"]

        @search_results = if @mapper.nil?
          hits
        else
          hits.map { |hit| @mapper.(hit) }
        end
      end

      private

      def response
        return @response if defined?(@response)
        @response = @client.search(@search_definition.to_search_args)
      end
    end

    class ScanCursor
      include Enumerable

      delegate :each, to: :enumerator

      def initialize(client, search_definition, document_klass, size: 100, scroll: "1m")
        @client            = client
        @search_definition = search_definition
        @document_klass    = document_klass
        @size              = size
        @scroll            = scroll
      end

      def empty?
        total == 0
      end

      def blank?
        empty?
      end

      def total
        search["hits"]["total"]
      end

      private

      def enumerator
        Enumerator.new do |y|
          response = search

          loop do
            response = @client.scroll(scroll_id: response["_scroll_id"], scroll: @scroll)
            hits     = response["hits"]["hits"]
            break if hits.empty?

            hits.each do |hit|
              y << @document_klass.from_hit(hit)
            end
          end
        end
      end

      def search
        return @search if defined?(@search)
        args    = @search_definition.to_search_args
        args    = args.merge(search_type: 'scan', size: @size, scroll: @scroll)
        @search = @client.search(args)
      end
    end

    class ActiveRecordProxy
      def self.from_hits(relation, hits)
        ids = hits.map { |hit| hit["_id"] }

        if ids.any?
          id_col = "#{relation.connection.quote_column_name(relation.table_name)}.#{relation.connection.quote_column_name(relation.klass.primary_key)}"
          relation.where("#{id_col} IN (?)", ids).order("FIELD(#{id_col},#{ids.join(',')})")
        else
          relation.none
        end
      end

      class Relation < ActiveSupport::ProxyObject
        def initialize(relation)
          @relation = relation
        end

        def method_missing(name, *args, &block)
          @relation.public_send(name, *args, &block)
        end

        def pretty_print(pp)
          pp.object_group(self) do
            pp.text " #{@relation.to_sql}"
          end
        end

        def inspect
          "#<#{self.class}: #{@relation.to_sql}>"
        end
      end

      def initialize(client, search_definition, relation)
        @client            = client
        @search_definition = search_definition.update(_source: false)
        @relation          = Relation.new(relation)
      end

      def metadata
        @metadata ||= { total: response["hits"]["total"], suggestions: response["hits"]["suggest"] || {} }
      end

      def total
        metadata[:total]
      end

      def suggestions
        metadata[:suggestions]
      end

      def method_missing(name, *args, **options, &block)
        filtered_relation.public_send(name, *args, **options, &block)
      end

      private

      def response
        @response ||= @client.search(@search_definition.to_search_args)
      end

      def filtered_relation
        return @filtered_relation if defined?(@filtered_relation)
        @filtered_relation = ActiveRecordProxy.from_hits(@relation, response["hits"]["hits"])
      end
    end

    class DocumentProxy < BasicObject
      def initialize(search, document_klass)
        @search         = search
        @document_klass = document_klass
      end

      delegate :search_definition, :active_records, to: :@search

      def documents
        @search.documents(@document_klass)
      end

      def scan_documents(**options)
        @search.scan_documents(@document_klass, **options)
      end

      def method_missing(method_name, *args, &block)
        documents.public_send(method_name, *args, &block)
      end
    end
  end
end
