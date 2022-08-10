# frozen_string_literal: true

module Elasticity
  class Config
    def client=(client)
      @client = Elasticity::InstrumentedClient.new(client)
    end

    def client
      return @client if defined?(@client)
      self.client = Elasticsearch::Client.new
      @client
    end

    attr_writer :settings, :namespace, :pretty_json

    def settings
      return @settings if defined?(@settings)
      @settings = {}
    end

    def namespace
      @namespace
    end

    def pretty_json
      @pretty_json || false
    end
  end
end
