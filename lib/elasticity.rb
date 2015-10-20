require "rubygems"
require "bundler/setup"
Bundler.setup

require "active_support"
require "active_support/core_ext"
require "active_model"
require "elasticsearch"

module Elasticity
  autoload :Bulk,               "elasticity/bulk"
  autoload :Config,             "elasticity/config"
  autoload :IndexConfig,        "elasticity/index_config"
  autoload :IndexMapper,        "elasticity/index_mapper"
  autoload :BaseDocument,       "elasticity/base_document"
  autoload :Document,           "elasticity/document"
  autoload :SegmentedDocument,  "elasticity/segmented_document"
  autoload :InstrumentedClient, "elasticity/instrumented_client"
  autoload :LogSubscriber,      "elasticity/log_subscriber"
  autoload :MultiSearch,        "elasticity/multi_search"
  autoload :Search,             "elasticity/search"
  autoload :Strategies,         "elasticity/strategies"

  def self.configure
    @config = Config.new
    yield(@config)
  end

  def self.config
    return @config if defined?(@config)
    @config = Config.new
  end
end

if defined?(Rails)
  require "elasticity/railtie"
end
