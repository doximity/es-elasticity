require "rubygems"
require "bundler/setup"
Bundler.setup

require "active_support"
require "active_support/core_ext"
require "active_model"
require "elasticsearch"

if defined?(Rails)
  require "elasticity/railtie"
end

module Elasticity
  class Config
    attr_writer :client, :settings, :namespace, :pretty_json

    def client
      return @client if defined?(@client)
      @client = Elasticsearch::Client.new
    end

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

  def self.configure
    @config = Config.new
    yield(@config)
  end

  def self.config
    return @config if defined?(@config)
    @config = Config.new
  end
end
