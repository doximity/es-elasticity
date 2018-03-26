require "elasticity/index_mapper"

RSpec.describe Elasticity::IndexMapper, elasticsearch: true do
  describe "single index strategy" do
    subject do
      Class.new(Elasticity::Document) do
        def self.name
          'SomeClass'
        end

        configure do |c|
          c.index_base_name = "users"
          c.document_type   = "user"
          c.strategy        = Elasticity::Strategies::SingleIndex

          c.mapping = {
            "properties" => {
              name: { type: "string", index: "not_analyzed" },
              birthdate: { type: "date" },
            },
          }
        end

        attr_accessor :name, :birthdate

        def to_document
          { name: name, birthdate: birthdate }
        end
      end
    end

    before do
      subject.recreate_index
      @elastic_search_client.cluster.health wait_for_status: 'yellow'
    end

    it "will not raise an exception on missing index if arg is passed in body" do
      subject.delete_index
      results = subject.search({"ignore_unavailable" => true})
      expect(results.total).to eq 0
    end

    it "will raise an exception on missing index if arg is not passed in body" do
      subject.delete_index
      results = subject.search({})
      expect { results.total }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
    end
  end
end
