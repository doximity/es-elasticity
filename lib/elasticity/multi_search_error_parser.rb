module Elasticity
  class MultiSearchErrorParser
    class Unknown < StandardError; end

    def self.parse(response)
      raise error_for(response["status"]), response.to_json
    end

    private

    def self.error_for(status)
      Elasticsearch::Transport::Transport::ERRORS[status] || Unknown
    end
  end
end
