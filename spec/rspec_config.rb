require "elasticity_base"
require "simplecov"
require "elasticity"

def elastic_search_client
  return @elastic_search_client if defined?(@elastic_search_client)
  @elastic_search_client = Elasticsearch::Client.new host: "http://0.0.0.0:9200"
end

logger = Logger.new("spec/log", File::WRONLY | File::APPEND | File::CREAT)

RSpec.configure do |c|
  c.disable_monkey_patching!

  c.before(:suite) do
    logger.info "rspec.init Starting test suite execution"
  end

  c.before(:each) do |example|
    logger.info "rspec.spec #{example.full_description}"

    if example.metadata[:elasticsearch]
      client = elastic_search_client
    end

    Elasticity.configure do |e|
      e.logger = logger
      e.client = client
    end
  end
end
