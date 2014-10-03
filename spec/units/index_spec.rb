require "elasticity/index"

RSpec.describe Elasticity::Index, elasticsearch: true do
  subject do
    described_class.new(Elasticity.config.client, "test_index_name")
  end

  let :index_def do
    {
      mappings: {
        document: {
          properties: {
            name: { type: "string" }
          }
        }
      }
    }
  end

  after do
    subject.delete_if_defined
  end

  it "allows creating, recreating and deleting an index" do
    subject.create(index_def)
    expect(subject.mappings).to eq({"document"=>{"properties"=>{"name"=>{"type"=>"string"}}}})

    subject.recreate
    expect(subject.mappings).to eq({"document"=>{"properties"=>{"name"=>{"type"=>"string"}}}})

    subject.delete
    expect(subject.mappings).to be nil
  end

  context "with existing index" do
    before do
      subject.create_if_undefined(index_def)
    end

    it "allows adding, getting and removing documents from the index" do
      subject.add_document("document", 1, name: "test")

      doc = subject.get_document("document", 1)
      expect(doc["_source"]["name"]).to eq("test")

      subject.remove_document("document", 1)
      expect { subject.get_document("document", 1) }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
    end

    it "allows searching documents" do
      subject.add_document("document", 1, name: "test")
      subject.flush
      results = subject.search("document", filter: { term: { name: "test" }})

      expect(results["hits"]["total"]).to be 1

      doc = results["hits"]["hits"][0]
      expect(doc["_id"]).to eq "1"
      expect(doc["_source"]).to eq({ "name" => "test" })
    end
  end

  it "returns nil for mapping and settings when index does not exist" do
    expect(subject.mappings).to be nil
    expect(subject.settings).to be nil
  end
end
