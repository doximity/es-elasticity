module Elasticity
  module Search
    def self.build(client, index_name, document_types, body)
      search_def = Search::Definition.new(index_name, document_types, body)
      Search::Facade.new(client, search_def)
    end

    # Elasticity::Search::Definition is a struct that encapsulates all the data specific to one
    # ElasticSearch search.
    class Definition
      attr_accessor :index_name, :document_types, :body

      def initialize(index_name, document_types, body)
        @index_name     = index_name
        @document_types = document_types
        @body           = body.deep_symbolize_keys!
      end

      def update(body_changes)
        self.class.new(@index_name, @document_types, @body.deep_merge(body_changes))
      end

      def to_count_args
        { index: @index_name, type: @document_types}.tap do |args|
          body = @body.slice(:query)
          args[:body] = body if body.present?
        end
      end

      def to_search_args
        { index: @index_name, type: @document_types, body: @body }
      end

      def to_msearch_args
        { index: @index_name, type: @document_types, search: @body }
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
      def document_hashes(search_args = {})
        return @document_hashes if defined?(@document_hashes)
        @document_hashes = LazySearch.new(@client, @search_definition, search_args)
      end

      # Performs the search using the default search type and returning an iterator that will yield
      # each document, converted using the provided mapper
      def documents(mapper, search_args = {})
        return @documents if defined?(@documents)
        @documents = LazySearch.new(@client, @search_definition, search_args) do |hit|
          mapper.(hit)
        end
      end

      # Performs the search using the scan search type and the scoll api to iterate over all the documents
      # as fast as possible. The sort option will be discarded.
      #
      # More info: http://www.elasticsearch.org/guide/en/elasticsearch/guide/current/scan-scroll.html
      def scan_documents(mapper, **options)
        return @scan_documents if defined?(@scan_documents)
        @scan_documents = ScanCursor.new(@client, @search_definition, mapper, **options)
      end

      # Performs the search only fetching document ids using it to load ActiveRecord objects from the provided
      # relation. It returns the relation matching the objects found on ElasticSearch.
      def active_records(relation)
        ActiveRecordProxy.new(@client, @search_definition, relation)
      end
    end

    class LazySearch
      include Enumerable

      delegate :each, :size, :length, :[], :+, :-, :&, :|, :total, :per_page,
        :total_pages, :current_page, :next_page, :previous_page, :aggregations, to: :search_results

      attr_accessor :search_definition

      def initialize(client, search_definition, search_args, &mapper)
        @client            = client
        @search_definition = search_definition
        @mapper            = mapper
        @search_args       = search_args
      end

      def empty?
        total == 0
      end

      def blank?
        empty?
      end

      def suggestions
        response["suggest"] ||= {}
      end

      def count(args = {})
        @client.count(@search_definition.to_count_args.reverse_merge(args))["count"]
      end

      def search_results
        @search_results ||= Search::Results.new(response, @search_definition.body, @mapper)
      end

      private

      def response
        return @response if defined?(@response)
        @response = @client.search(@search_definition.to_search_args.reverse_merge(@search_args))
      end
    end

    class ScanCursor
      include Enumerable

      def initialize(client, search_definition, mapper, size: 100, scroll: "1m")
        @client            = client
        @search_definition = search_definition
        @mapper            = mapper
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

      def each_batch
        enumerator.each do |group|
          yield(group)
        end
      end

      def each
        enumerator.each do |group|
          group.each { |doc| yield(doc) }
        end
      end

      private

      def enumerator
        Enumerator.new do |y|
          response = search

          loop do
            response = @client.scroll(scroll_id: response["_scroll_id"], scroll: @scroll)
            break if response["hits"]["hits"].empty?

            y << Search::Results.new(response, @search_definition.body, @mapper)
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
      def self.map_response(relation, body, response)
        ids = response["hits"]["hits"].map { |hit| hit["_id"] }

        if ids.any?
          id_col  = "#{relation.connection.quote_column_name(relation.table_name)}.#{relation.connection.quote_column_name(relation.klass.primary_key)}"
          id_vals = ids.map { |id| relation.connection.quote(id) }
          Relation.new(relation.where("#{id_col} IN (?)", ids).order("FIELD(#{id_col}, #{id_vals.join(',')})"), body, response)
        else
          Relation.new(relation.none, body, response)
        end
      end

      class Relation < ActiveSupport::ProxyObject

        delegate :total, :per_page, :total_pages, :current_page, :next_page,
          :previous_page, :aggregations, to: :@results

        def initialize(relation, search_definition, response)
          @relation = relation
          @search_definition = search_definition
          @response = response
          @results = Results.new(response, search_definition)
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
        @relation          = relation
      end

      def metadata
        @metadata ||= { total: response["hits"]["total"], suggestions: response["suggest"] || {} }
      end

      def total
        metadata[:total]
      end

      def suggestions
        metadata[:suggestions]
      end

      def method_missing(name, *args, &block)
        filtered_relation.public_send(name, *args, &block)
      end

      private

      def response
        @response ||= @client.search(@search_definition.to_search_args)
      end

      def filtered_relation
        return @filtered_relation if defined?(@filtered_relation)
        @filtered_relation = ActiveRecordProxy.map_response(@relation, @search_definition.body, response)
      end
    end

    class DocumentProxy < BasicObject
      def initialize(search, document_klass)
        @search         = search
        @document_klass = document_klass
      end

      delegate :search_definition, :active_records, to: :@search

      def documents(search_args = {})
        @search.documents(@document_klass, search_args)
      end

      def scan_documents(**options)
        @search.scan_documents(@document_klass, **options)
      end

      def method_missing(method_name, *args, &block)
        documents.public_send(method_name, *args, &block)
      end
    end

    class Results < ActiveSupport::ProxyObject
      include ::Enumerable

      delegate :each, :size, :length, :[], :+, :-, :&, :|, to: :@documents

      DEFAULT_SIZE = 10

      def initialize(response, body, mapper = nil)
        @response = response
        @body = body
        begin
          @documents = if mapper.nil?
            @response["hits"]["hits"]
          else
            @response["hits"]["hits"].map { |hit| mapper.(hit) }
          end
        rescue NoMethodError
      end

      def method_missing(name, *args, &block)
        @documents.public_send(name, *args, &block)
      end

      def each(&block)
        @documents.each(&block)
      end

      def aggregations
        @response["aggregations"] ||= {}
      end

      def total
        @response["hits"]["total"]
      end
      alias_method :total_entries, :total

      # for pagination
      def total_pages
        (total.to_f / per_page.to_f).ceil
      end

      # for pagination
      def per_page
        @body[:size] || DEFAULT_SIZE
      end

      # for pagination
      def current_page
        return 1 if @body[:from].nil?
        @body[:from] / per_page + 1
      end

      def next_page
        current_page < total_pages ? (current_page + 1) : nil
      end

      def previous_page
        current_page > 1 ? (current_page - 1) : nil
      end
    end
  end
end
