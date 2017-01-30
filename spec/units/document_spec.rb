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
      def self.name
        "SomeClass"
      end

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
    allow(Elasticity::Strategies::AliasIndex).to receive(:new).and_return(strategy)
  end

  it "requires subclasses to define to_document method" do
    expect { Class.new(described_class).new.to_document }.to raise_error(NotImplementedError)
  end

  context "instance" do
    subject { klass.new _id: 1, name: "Foo", items: [{ name: "Item1" }] }

    it "stores the document in the strategy" do
      expect(strategy).to receive(:index_document).with("class_name", 1, { name: "Foo", items: [{ name: "Item1" }] }).and_return("_id" => "1", "created" => true)
      subject.update
    end
  end
end
