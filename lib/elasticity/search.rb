module Elasticity
  class Search
    class Result
      include Enumerable

      def initialize(response, mapper)
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
        @mapping = @mapper.map(hits)
      end
    end

    class DocumentMapper
      def initialize(document_klass)
        @document_klass = document_klass
      end

      def map(hits)
        hits.map do |hit|
          @document_klass.new(hit["_source"])
        end
      end
    end

    class ActiveRecordMapper
      def initialize(relation)
        @relation = relation
      end

      def map(hits)
        ids = hits.map { |h| h["_source"]["id"] }

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

    def initialize(index, document_type, body)
      @index          = index
      @document_type  = document_type.freeze
      @body           = body.freeze
    end

    def active_records(relation)
      return @active_record if defined?(@active_record)
      response = @index.search(@document_type, @body.merge(_source: ["id"]))
      @active_record = Result.new(response, ActiveRecordMapper.new(relation))
    end

    def documents(document_klass)
      return @documents if defined?(@documents)
      response   = @index.search(@document_type, @body)
      @documents = Result.new(response, DocumentMapper.new(document_klass))
    end
  end
end
