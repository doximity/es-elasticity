require "elasticity/index_mapper"

RSpec.describe Elasticity::IndexMapper do
  describe "checking for subclasses" do
    class SomeKlass < Elasticity::Document
    end

    context "when subclasses are supported by ES version" do
      it "does not raise exception when config has subclasses" do
        stub_strategy_methods
        config = stub_config("5.3.2", ["dogs", "cats"])
        expect(config).to receive(:definition).twice.and_return({})
        index_mapper = Elasticity::IndexMapper.new(SomeKlass, config)
        expect{ index_mapper.create_index }.to_not raise_error()
        expect{ index_mapper.recreate_index }.to_not raise_error()
        expect{ index_mapper.index_document("22", {}) }.to_not  raise_error()
      end

    end
    context "when subclasses are not supported by ES version" do
      it "raises exception on some methods" do
        index_mapper = Elasticity::IndexMapper.new(SomeKlass, stub_config("6.0.2", ["dogs", "cats"]))
        expect{ index_mapper.create_index }.to raise_error(Elasticity::IndexConfig::SubclassError)
        expect{ index_mapper.recreate_index }.to raise_error(Elasticity::IndexConfig::SubclassError)
        expect{ index_mapper.index_document("22", {}) }.to raise_error(Elasticity::IndexConfig::SubclassError)
      end

      it "does not raise exception when config has no subclasses" do
        stub_strategy_methods
        index_mapper = Elasticity::IndexMapper.new(SomeKlass, stub_config("6.0.2"))
        expect{ index_mapper.create_index }.to_not raise_error()
        expect{ index_mapper.recreate_index }.to_not raise_error()
        expect{ index_mapper.index_document("22", {}) }.to_not  raise_error()
      end
    end

    def stub_config(version, subclasses=nil)
      # silence the warnings for these tests
      allow(Warning).to receive(:warn)
      Elasticity::IndexConfig.new(
        double("es_config", settings: {}, namespace: nil, client: double("client", versions: [version])),
        {
          index_base_name: "some_name",
          document_type: "some_type",
          subclasses: subclasses
        }
      ){}
    end

    def stub_strategy_methods
      allow_any_instance_of(Elasticity::Strategies::AliasIndex).to receive(:create_if_undefined)
      allow_any_instance_of(Elasticity::Strategies::AliasIndex).to receive(:recreate)
      allow_any_instance_of(Elasticity::Strategies::AliasIndex).to receive(:index_document)
    end
  end
end
