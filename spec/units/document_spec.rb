require "elasticity/search"

RSpec.describe Elasticity::Document do
  mappings = {
    properties: {
      name: { type: "string" },

      items: {
        type: "nested",
        properties: {
          name: { type: "string" },
        },
      }
    }
  }

  let :klass do
    Class.new(described_class) do
      configure do |c|
        c.index_base_name = "class_names"
        c.document_type   = "class_name"
        c.mapping         = mappings
      end

      attr_accessor :name, :items

      def to_document
        { name: name, items: items }
      end
    end
  end

  let :strategy do
    double(:strategy)
  end

  before :each do
    allow(Elasticity::Strategies::SingleIndex).to receive(:new).and_return(strategy)
  end

  it "requires subclasses to define to_document method" do
    expect { Class.new(described_class).new.to_document }.to raise_error(NotImplementedError)
  end

  context "class" do
    subject { klass }

    it "properly instantiate from search hit" do
      hit = { "_id" => 1, "_source" => { "name" => "foo", "items" => [{ name: "bar" }] }, "highlight" => { "name" => "<em>foo</em>" } }
      doc = subject.from_hit(hit)
      expect(doc.name).to eq "foo"
      expect(doc.items).to eq [{ name: "bar" }]
      expect(doc.highlighted.name).to eq "<em>foo</em>"
      expect(doc.highlighted.items).to eq [{ name: "bar" }]
    end

    it "searches using DocumentSearch" do
      body   = double(:body)
      search = double(:search)

      expect(strategy).to receive(:search).with("class_name", body).and_return(search)

      doc_search = double(:doc_search)
      expect(Elasticity::Search::DocumentProxy).to receive(:new).with(search, subject).and_return(doc_search)

      expect(subject.search(body)).to be doc_search
    end

    it "gets specific document from the strategy" do
      doc = { "_id" => 1, "_source" => { "name" => "Foo", "items" => [{ "name" => "Item1" }]}}
      expect(strategy).to receive(:get_document).with("class_name", 1).and_return(doc)
      expect(subject.get(1)).to eq klass.new(_id: 1, name: "Foo", items: [{ "name" => "Item1" }])
    end

    it "deletes specific document from strategy" do
      strategy_ret = double(:strategy_return)
      expect(strategy).to receive(:delete_document).with("class_name", 1).and_return(strategy_ret)
      expect(subject.delete(1)).to eq strategy_ret
    end

    it "properly instantiates from search hit when no source is given" do
      hit = { "_id" => 1, "_type" => "foo" }
      doc = subject.from_hit(hit)
      expect(doc._id).to eq(1)
    end
  end

  context "instance" do
    subject { klass.new _id: 1, name: "Foo", items: [{ name: "Item1" }] }

    it "stores the document in the strategy" do
      expect(strategy).to receive(:index_document).with("class_name", 1, { name: "Foo", items: [{ name: "Item1" }] }).and_return("_id" => "1", "created" => true)
      subject.update
    end
  end
end
