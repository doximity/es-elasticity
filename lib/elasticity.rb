require "rubygems"
require "bundler/setup"
Bundler.setup

require "active_support"
require "active_support/core_ext"
require "active_model"

require "elasticity/index"
require "elasticity/document"
require "elasticity/result_set"
require "elasticity/search"
require "elasticity/multi_search"

module Elasticity
  Config = Struct.new(:client, :logger)

  def self.configure
    @config = yield(Config.new)
    initialize!
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
