require "elasticity/index"

RSpec.describe Elasticity::Index, elasticsearch: true do
  subject do
    described_class.new(Elasticity.config.client, "test_index_name",
      mappings: {
        document: {
          properties: {
            name: { type: "string" }
          }
        }
      }
    )
  end

  after :each do
    subject.delete_if_defined
  end

  it "allows creating, recreating and deleting an index" do
    subject.create
    expect(subject.mapping).to eq({"test_index_name"=>{"mappings"=>{"document"=>{"properties"=>{"name"=>{"type"=>"string"}}}}}})

    subject.recreate
    expect(subject.mapping).to eq({"test_index_name"=>{"mappings"=>{"document"=>{"properties"=>{"name"=>{"type"=>"string"}}}}}})

    subject.delete
    expect(subject.mapping).to be nil
  end
end
