module Elasticity
  class ResultSet
    include Enumerable

    def initialize(document_klass, response)
      @document_klass = document_klass
      @response        = response
    end

    delegate :each, :to_ary, to: :documents

    def total
      @response["hits"]["total"]
    end

    def empty?
      total == 0
    end

    def blank?
      empty?
    end

    def documents
      return @documents if defined?(@documents)

      @documents = @response["hits"]["hits"].map do |hit|
        @document_klass.from_document(hit)
      end
    end

    def database(relation)
      ids = @response["hits"]["hits"].map { |h| h["_source"]["id"] }

      if ids.any?
        id_col = "#{relation.connection.quote_column_name(relation.table_name)}.#{relation.connection.quote_column_name("id")}"
        relation.where(id: ids).order("FIELD(#{id_col},#{ids.join(',')})")
      else
        relation.none
      end
    end
  end
end
