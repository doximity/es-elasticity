# Copyright 2015 Doximity, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
  autoload :ScrollableSearch,   "elasticity/scrollable_search"

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
