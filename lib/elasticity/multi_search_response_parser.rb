module Elasticity
  class MultiSearchResponseParser
    class UnknownError < StandardError; end

    def self.parse(response, search, skip_raise_on_errors: false)
      if response["error"]
        exception = error_for(response["status"]).new(response.to_json)
        raise(exception) unless skip_raise_on_errors
        null_response = {
          "hits" => {
            "total" => 0,
            "hits" => []
           },
           "aggregations" => {},
           "error" => response["error"],
           "exception" => exception
        }

        return Search::Results.new(null_response, search[:search_definition].body)
      end

      case
      when search[:documents]
        Search::Results.new(response, search[:search_definition].body, search[:documents].method(:map_hit))
      when search[:active_records]
        Search::ActiveRecordProxy.map_response(search[:active_records], search[:search_definition].body, response)
      end
    end

    private

    def self.error_for(status)
      Elasticsearch::Transport::Transport::ERRORS[status] || UnknownError
    end
  end
end
