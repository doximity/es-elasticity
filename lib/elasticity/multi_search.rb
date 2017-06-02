module Elasticity
  class MultiSearch

    def initialize(msearch_args = {})
      @results  = {}
      @searches = {}
      @mappers  = {}
      @msearch_args = msearch_args
      yield self if block_given?
    end

    def add(name, search, documents: nil, active_records: nil)
      if !documents.nil? && !active_records.nil?
        raise ArgumentError, "you can only pass either :documents or :active_records as an option"
      elsif documents.nil? && active_records.nil?
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
      # FIXME: How to initialize results
      @results[name] ||= result_for(name)
    end

    private

    def result_for(name)
      index  = @searches.keys.index(name)
      search = @searches[name]
      resp   = response["responses"][index]

      case
      when search[:documents]
        Search::Results.new(resp, search[:search_definition].body, search[:documents].method(:map_hit))
      when search[:active_records]
        Search::ActiveRecordProxy.map_response(search[:active_records], search[:search_definition].body, resp)
      end
    end

    def response
      @response ||= ActiveSupport::Notifications.instrument("multi_search.elasticity", args: { body: bodies }) do
        args = { body: bodies.map(&:dup) }.reverse_merge(@msearch_args)
        Elasticity.config.client.msearch(args)
      end
    end

    def bodies
      @bodies ||= @searches.values.map do |hsh|
        hsh[:search_definition].to_msearch_args
      end
    end
  end
end
