module Elasticity
  class Search
    include Enumerable

    def initialize(index, doc_type, document_klass, body)
      @index          = index
      @document_type  = doc_type.freeze
      @document_klass = document_klass
      @body           = self.class.construct_body(body).freeze
    end

    # Allow getting the name for the index that will be searched
    def index_name
      @index.name
    end

    # Allow querying for the search document type
    attr_reader :document_type

    # Allow querying for the document klass
    attr_reader :document_klass

    # Allow grabbing the underlying body of the query
    attr_reader :body

    delegate :each, :to_ary, :total, :empty?, :blank?, :documents, to: :document_result_set

    # Takes a ActiveRecord::Relation and search elasticsearch grabbing all the IDs from
    # matched records, then it augments the provided relation to only match on the specified IDs.
    # The result is a collection of ActiveRecord models.
    def database(relation)
      @database_rs ||= document_result_set || ResultSet.new(@document_klass, execute(_source: ["id"]))
      @database_rs.database(relation)
    end

    private

    def self.construct_body(body)
      case body
      when Hash
        body
      when String
        ActiveSupport::JSON.decode(body)
      else
        raise ArgumentError, "unsupported type for body: #{body.class}"
      end
    end

    def execute(extra = {})
      @index.search(@document_type, @body.deep_merge(extra))
    end

    def document_result_set
      @documents_rs ||= ResultSet.new(@document_klass, execute)
    end
  end
end
