module Elasticity
  class Search
    class Result
      include Enumerable

      def initialize(response, &mapper)
        @response = response
        @mapper   = mapper
      end

      delegate :[], :each, :to_ary, :length, :size, to: :mapping

      def total
        @response["hits"]["total"]
      end

      def empty?
        total == 0
      end

      def blank?
        empty?
      end

      def hits
        @response["hits"]["hits"]
      end

      def mapping
        return @mapping if defined?(@mapping)
        @mapping = @mapper.(hits)
      end
    end

    def initialize(index, document_type, body, &mapper)
      @index         = index
      @document_type = document_type.freeze
      @body          = body.freeze
      @mapper        = mapper
    end

    delegate :[], :each, :to_ary, :length, :size, :total, :empty?, :blank?, :hits, to: :documents

    def database(relation)
      return @database if defined?(@database)

      @database = Result.new(@index.search(@document_type, @body.merge(_source: ["id"]))) do |hits|
        ids = hits.map { |h| h["_source"]["id"] }

        if ids.any?
          id_col = "#{relation.connection.quote_column_name(relation.table_name)}.#{relation.connection.quote_column_name("id")}"
          relation.where(id: ids).order("FIELD(#{id_col},#{ids.join(',')})")
        else
          relation.none
        end
      end
    end

    def documents
      return @documents if defined?(@documents)

      @documents = Result.new(@index.search(@document_type, @body)) do |hits|
        hits.map { |hit| @mapper.(hit) }
      end
    end
  end
end
