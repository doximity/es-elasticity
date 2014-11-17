RSpec.describe Elasticity::Strategies::SingleIndex, elasticsearch: true do
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

    subject.recreate(index_def)
    expect(subject.mappings).to eq({"document"=>{"properties"=>{"name"=>{"type"=>"string"}}}})

    subject.delete
    expect(subject.mappings).to be nil
  end

  it "returns nil for mapping and settings when index does not exist" do
    expect(subject.mappings).to be nil
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
      expect(results_a).to include("errors"=>false, "items"=>[{"index"=>{"_index"=>"test_index_name", "_type"=>"document", "_id"=>"1", "_version"=>1, "status"=>201}}])

      results_b = subject.bulk do |b|
        b.index  "document", 2, name: "bar"
        b.delete "document", 1
      end

      expect(results_b).to include("errors"=>false, "items"=>[{"index"=>{"_index"=>"test_index_name", "_type"=>"document", "_id"=>"2", "_version"=>1, "status"=>201}}, {"delete"=>{"_index"=>"test_index_name", "_type"=>"document", "_id"=>"1", "_version"=>2, "status"=>200, "found"=>true}}])

      subject.flush

      expect { subject.get_document("document", 1) }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
      expect(subject.get_document("document", 2)).to eq({"_index"=>"test_index_name", "_type"=>"document", "_id"=>"2", "_version"=>1, "found"=>true, "_source"=>{"name"=>"bar"}})
    end

    it "allows searching documents" do
      subject.index_document("document", 1, name: "test")
      subject.flush

      search = subject.search("document", filter: { term: { name: "test" }})
      hashes = search.document_hashes
      expect(hashes.size).to be 1
      expect(hashes[0]).to eq("_id" => "1", "_index" => "test_index_name", "_type" => "document", "_score" => 1.0, "_source" => { "name" => "test" })
    end

    it "allows deleting by queryu" do
      subject.index_document("document", 1, name: "foo")
      subject.index_document("document", 2, name: "bar")

      subject.delete_by_query("document", query: { term: { name: "foo" }})

      expect { subject.get_document("document", 1) }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
      expect { subject.get_document("document", 2) }.to_not raise_error

      subject.flush
    end
  end
end
