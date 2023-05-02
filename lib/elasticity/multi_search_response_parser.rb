module Elasticity
  class MultiSearchResponseParser
    class UnknownError < StandardError; end

    def self.parse(response, search)
      raise error_for(response["status"]), response.to_json if response["error"]

      case
      when search[:documents]
        Search::Results.new(response, search[:search_definition].body, search[:documents].method(:map_hit))
      when search[:active_records]
        Search::ActiveRecordProxy.map_response(search[:active_records], search[:search_definition].body, response)
      end
    end

    private

    def self.error_for(status)
      Elastic::Transport::Transport::ERRORS[status] || UnknownError
    end
  end
end
