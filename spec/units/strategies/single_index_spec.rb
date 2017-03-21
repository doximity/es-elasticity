RSpec.describe Elasticity::Strategies::SingleIndex, elasticsearch: true do
  subject do
    described_class.new(Elasticity.config.client, "test_index_name", "document")
  end

  let :index_def do
    {
      "mappings" => {
        "document" => {
          "properties" => {
            "name" => { "type" => "text" }
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
    expect(subject.mapping).to eq(index_def)

    subject.recreate(index_def)
    expect(subject.mapping).to eq(index_def)

    subject.delete
    expect(subject.mapping).to be nil
  end

  it "returns nil for mapping and settings when index does not exist" do
    expect(subject.mapping).to be nil
    expect(subject.settings).to be nil
  end

  context "with existing index" do
    before do
      subject.create_if_undefined(index_def)
    end

    it "allows adding, getting and removing documents from the index" do
      subject.index_document("document", 1, name: "test")

      doc = subject.get_document("document", 1)
      expect(doc["_source"]["name"]).to eq("test")

      subject.delete_document("document", 1)
      expect { subject.get_document("document", 1) }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
    end

    it "allows batching index and delete actions" do
      results_a = subject.bulk do |b|
        b.index "document", 1, name: "foo"
      end
      expect(results_a["errors"]).to be_falsey

      results_b = subject.bulk do |b|
        b.index  "document", 2, name: "bar"
        b.delete "document", 1
      end

      expect(results_b["errors"]).to be_falsey

      subject.flush

      expect { subject.get_document("document", 1) }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
      expect(subject.get_document("document", 2)).to eq({"_index"=>"test_index_name", "_type"=>"document", "_id"=>"2", "_version"=>1, "found"=>true, "_source"=>{"name"=>"bar"}})
    end

    it "allows deleting by query" do
      subject.index_document("document", 1, name: "foo")
      subject.index_document("document", 2, name: "bar")

      subject.flush
      subject.delete_by_query("document", query: { term: { name: "foo" } })

      expect { subject.get_document("document", 1) }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
      expect { subject.get_document("document", 2) }.to_not raise_error

      subject.flush
    end
  end
end
