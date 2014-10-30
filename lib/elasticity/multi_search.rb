module Elasticity
  class MultiSearch
    def initialize
      @searches = {}
      @mappers  = {}
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

      @searches[name] = { index: search.index_name, type: search.document_type, search: search.body }
      @mappers[name]  = mapper
      name
    end

    def [](name)
      @results ||= fetch
      @results[name]
    end

    private

    def fetch
      bodies = @searches.values.map(&:dup)

      response = ActiveSupport::Notifications.instrument("multi_search.elasticity", args: { body: @searches.values }) do
        Elasticity.config.client.msearch(body: bodies)
      end

      results = {}

      @searches.keys.each_with_index do |name, idx|
        resp          = response["responses"][idx]
        mapper        = @mappers[name]
        results[name] = Search::Result.new(resp, mapper)
      end

      results
    end
  end
end
