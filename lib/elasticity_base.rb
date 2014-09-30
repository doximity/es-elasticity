require "rubygems"
require "bundler/setup"
Bundler.setup

require "active_support"
require "active_support/core_ext"
require "active_model"
require "elasticsearch"

module Elasticity
  class Config
    class_attribute :logger
    self.logger = Logger.new(STDOUT)

    class_attribute :client
    self.client = nil

    class_attribute :settings
    self.settings = {}

    class_attribute :namespace
    self.settings = nil
  end

  def self.configure
    @config = Config.new
    yield(@config)
  end

  def self.config
    @config
  end

  def self.client
    if @config
      @config.client
    end
  end
end

ActiveSupport::Notifications.subscribe(/^elasticity\./) do |name, start, finish, id, payload|
  time = (finish - start)*1000

  if logger = Elasticity.config.logger
    logger.debug "#{name} #{"%.2f" % time}ms #{MultiJson.dump(payload, pretty: false)}"
  end
end
