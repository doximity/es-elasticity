require "rubygems"
require "bundler/setup"
Bundler.setup

require "active_support"
require "active_support/core_ext"
require "active_model"
require "elasticsearch"

module Elasticity
  class Config
    attr_writer :logger, :client, :settings, :namespace

    def logger
      return @logger if defined?(@logger)
      @logger = Logger.new(STDOUT)
    end

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

ActiveSupport::Notifications.subscribe(/^elasticity\./) do |name, start, finish, id, payload|
  time = (finish - start)*1000

  if logger = Elasticity.config.logger
    logger.debug "#{name} #{"%.2f" % time}ms #{MultiJson.dump(payload[:args], pretty: false)}"

    exception, message = payload[:exception]
    if exception
      logger.error "#{name} #{exception}: #{message}"
    end
  end
end
