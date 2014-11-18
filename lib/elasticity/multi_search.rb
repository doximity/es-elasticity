module Elasticity
  class MultiSearch
    def initialize
      @searches = {}
      @mappers  = {}
      yield self if block_given?
    end

    def add(name, search, documents: nil, active_records: nil)
      if documents && active_records
        raise ArgumentError, "you can only pass either :documents or :active_records as an option"
      elsif documents.blank? && active_records.blank?
        raise ArgumentError, "you need to provide either :documents or :active_records as an option"
      end

      @searches[name] = {
        search_definition: search.search_definition,
        documents: documents,
        active_records: active_records
      }

      name
    end

    def [](name)
      @results ||= fetch
      @results[name]
    end

    private

    def fetch
      bodies = @searches.values.map do |hsh|
        hsh[:search_definition].to_msearch_args
      end

      response = ActiveSupport::Notifications.instrument("multi_search.elasticity", args: { body: bodies }) do
        Elasticity.config.client.msearch(body: bodies.map(&:dup))
      end

      results = {}

      @searches.keys.each_with_index do |name, idx|
        resp = response["responses"][idx]
        search = @searches[name]

        results[name] = case
        when search[:documents]
          resp["hits"]["hits"].map { |hit| search[:documents].from_hit(hit) }
        when search[:active_records]
          Search::ActiveRecordProxy.from_hits(search[:active_records], resp["hits"]["hits"])
        end
      end

      results
    end
  end
end
