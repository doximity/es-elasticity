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
      elasticity_attributes :name, :items

      def self.name
        "SomeClass"
      end

      configure do |c|
        c.index_base_name = "class_names"
        c.document_type   = "class_name"
        c.mapping         = mappings
      end
    end
  end

  let :strategy do
    double(:strategy)
  end

  before :each do
    allow(Elasticity::Strategies::SingleIndex).to receive(:new).and_return(strategy)
  end

  context "instance" do
    subject { klass.new _id: 1, name: "Foo", items: [{ name: "Item1" }] }

    it "stores the document in the strategy" do
      expect(strategy).to receive(:index_document).with("class_name", 1, { name: "Foo", items: [{ name: "Item1" }] }).and_return("_id" => "1", "created" => true)
      subject.update
    end
  end


  context 'from_active_record' do
    let(:model) { double(id: 1, name: 'Window', items: ['glass', 'lock'] ) }

    it "converts the model to a document instance" do
      doc = klass.from_active_record(model)
      expect(doc.name).to eql('Window')
      expect(doc.items).to eql(['glass', 'lock'])
    end
  end
end
