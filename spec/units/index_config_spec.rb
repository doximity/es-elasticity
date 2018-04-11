require 'elasticity/index_config'

RSpec.describe Elasticity::IndexConfig do
  let(:elasticity_config) { double }
  subject {  }

    let(:defaults) do
      {
        index_base_name: 'users',
        document_type: 'user'
      }
    end

  it 'accepts default configuration options' do
    config = described_class.new(elasticity_config, defaults) {}
    expect(config.index_base_name).to eql('users')
    expect(config.document_type).to eql('user')
  end

  it 'overrides defaults' do
    config = described_class.new(elasticity_config, defaults) do |c|
      c.index_base_name = 'user_documents'
      c.document_type = 'users'
    end

    expect(config.index_base_name).to eql('user_documents')
    expect(config.document_type).to eql('users')
  end

  describe "subclass warnings" do
    class Multied < Elasticity::Document
    end

    it "warns if multi_mapping is not supported by the ES version" do
      stub_version("6.0.2")
      expect do
        Multied.configure do |c|
          c.index_base_name = "cats_and_dogs"
          c.strategy = Elasticity::Strategies::SingleIndex
          c.subclasses = { cat: "Cat", dog: "Dog" }
        end
      end.to output(Elasticity::IndexConfig::SUBCLASSES_NOT_AVAILABLE).to_stderr
    end

    it "does not warn if multi_mapping is supported by the ES version" do
      stub_version("5.3.1")
      expect do
        Multied.configure do |c|
          c.index_base_name = "cats_and_dogs"
          c.strategy = Elasticity::Strategies::SingleIndex
          c.subclasses = { cat: "Cat", dog: "Dog" }
        end
      end.to_not output.to_stderr
    end

    it "does not warn when no subclasses are configured" do
      stub_version("6.0.2")
      expect do
        Multied.configure do |c|
          c.index_base_name = "cats_and_dogs"
          c.strategy = Elasticity::Strategies::SingleIndex
        end
      end.to_not output.to_stderr
    end

    def stub_version(version)
      allow_any_instance_of(Elasticity::InstrumentedClient).to receive(:versions).and_return([version])
    end
  end
end
