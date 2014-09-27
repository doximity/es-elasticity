require "elasticity_base"
require "simplecov"
require "elasticity"

def elastic_search_client
  return @elastic_search_client if defined?(@elastic_search_client)
  @elastic_search_client = Elasticsearch::Client.new host: "http://0.0.0.0:9200"
end

RSpec.configure do |c|
  c.disable_monkey_patching!

  c.before(:each) do |example|
    if example.metadata[:elasticsearch]
      client = elastic_search_client
    end

    Elasticity.configure do |e|
      e.logger = Logger.new("spec/log", File::WRONLY | File::APPEND | File::CREAT)
      e.client = client
    end
  end
end
