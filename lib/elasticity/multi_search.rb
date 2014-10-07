module Elasticity
  class MultiSearch
    def initialize
      @searches = []
      yield self if block_given?
    end

    def add(name, search, documents: nil, active_records: nil)
      mapper = case
      when documents && active_records
        raise ArgumentError, "you can only pass either :documents or :active_records as an option"
      when documents
        Search::DocumentMapper.new(documents)
      when active_records
        Search::ActiveRecordMapper.new(active_records)
      else
        raise ArgumentError, "you need to provide either :documents or :active_records as an option"
      end

      @searches << [name, search, mapper]
    end

    def [](name)
      @results ||= fetch
      @results[name]
    end

    private

    def fetch
      multi_body = @searches.map do |name, search, _|
        { index: search.index.name, type: search.document_type, search: search.body }
      end

      results = {}

      responses = Array(Elasticity.config.client.msearch(body: multi_body)["responses"])
      responses.each_with_index do |resp, idx|
        name, search, mapper = @searches[idx]
        results[name] = Search::Result.new(resp, mapper)
      end

      results
    end
  end
end
