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

  subject do
    Class.new(described_class) do
      # Override the name since this is an anonymous class
      def self.name
        "ClassName"
      end

      define_mappings(mappings)
    end
  end

  let :index do
    double(:index, create_if_undefined: nil, name: "elasticity_test_class_names")
  end

  before :each do
    allow(Elasticity::Index).to receive(:new).and_return(index)
  end

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

  pending "defines the accessors based on the mappings" do
    subject.new id: 1, name: "Foo", items: [{ name: "Item1" }]
    expect(subject.id).to eq 1
    expect(subject.name).to eq "Foo"
    expect(subject.items[0].name).to eq "Item1"
  end
end
