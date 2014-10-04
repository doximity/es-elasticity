require "elasticity/search"

RSpec.describe Elasticity::Document do
  mappings = {
    properties: {
      id: { type: "integer" },
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
      # Override the name since this is an anonymous class
      def self.name
        "ClassName"
      end

      define_mappings(mappings)

      attr_accessor :name, :items

      def to_document
        { id: id, name: name, items: items}
      end
    end
  end

  let :index do
    double(:index, create_if_undefined: nil, name: "elasticity_test_class_names")
  end

  before :each do
    allow(Elasticity::Index).to receive(:new).and_return(index)
  end

  it "requires subclasses to define to_document method" do
    expect { Class.new(described_class).new.to_document }.to raise_error(NotImplementedError)
  end

  context "class" do
    subject { klass }

    it "extracts index name and document type from the class name" do
      expect(subject.index_name).to eq "elasticity_test_class_names"
      expect(subject.document_type).to eq "class_name"
    end

    it "have an associated Index instance" do
      client   = double(:client)
      settings = double(:settings)

      Elasticity.config.settings = settings
      Elasticity.config.client   = client

      expect(Elasticity::Index).to receive(:new).with(client, "elasticity_test_class_names").and_return(index)
      expect(index).to receive(:create_if_undefined).with(settings: settings, mappings: mappings)

      expect(subject.index).to be index
    end

    it "searches using DocumentSearch" do
      body   = double(:body)
      search = double(:search)
      expect(Elasticity::Search).to receive(:new).with(index, "class_name", body).and_return(search)

      doc_search = double(:doc_search)
      expect(Elasticity::DocumentSearchProxy).to receive(:new).with(search, subject).and_return(doc_search)

      expect(subject.search(body)).to be doc_search
    end

    it "gets specific document from the index" do
      doc = { "_source" => { "id" => 1, "name" => "Foo", "items" => [{ "name" => "Item1" }]}}
      expect(index).to receive(:get_document).with("class_name", 1).and_return(doc)
      expect(subject.get(1)).to eq klass.new(id: 1, name: "Foo", items: [{ "name" => "Item1" }])
    end

    it "removes specific document from index" do
      index_ret = double(:index_return)
      expect(index).to receive(:remove_document).with("class_name", 1).and_return(index_ret)
      expect(subject.remove(1)).to eq index_ret
    end
  end

  context "instance" do
    subject { klass.new id: 1, name: "Foo", items: [{ name: "Item1" }] }

    it "stores the document in the index" do
      expect(index).to receive(:add_document).with("class_name", 1, {id: 1, name: "Foo", items: [{ name: "Item1" }]})
      subject.save
    end
  end
end
