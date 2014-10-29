require "elasticity_base"
require "codeclimate-test-reporter"
require "simplecov"
require "oj"

CodeClimate::TestReporter.start

require "elasticity"
require "elasticity/log_subscriber"

def elastic_search_client
  return @elastic_search_client if defined?(@elastic_search_client)
  @elastic_search_client = Elasticsearch::Client.new host: "http://0.0.0.0:9200"
end

logger = Logger.new("spec/spec.log", File::WRONLY | File::APPEND | File::CREAT)
# logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

ActiveSupport::LogSubscriber.logger = logger
Elasticity::LogSubscriber.attach_to(:elasticity)

RSpec.configure do |c|
  c.disable_monkey_patching!

  c.before(:suite) do
    logger.info "init.rspec Starting test suite execution"
  end

  c.before(:each) do |example|
    logger.info "spec.rspec #{example.full_description}"

    if example.metadata[:elasticsearch]
      client = elastic_search_client
    else
      client = double(:elasticsearch_client)
    end

    Elasticity.configure do |e|
      e.client    = client
      e.namespace = "elasticity_test"
    end
  end
end
