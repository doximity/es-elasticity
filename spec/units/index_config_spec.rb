# frozen_string_literal: true

require "elasticity/index_config"

RSpec.describe Elasticity::IndexConfig do
  let(:elasticity_config) { double("config", client: double("client", versions: ["5.3.4"])) }
  subject {  }

    let(:defaults) do
      {
        index_base_name: "users",
        document_type: "user"
      }
    end

  it "accepts default configuration options" do
    config = described_class.new(elasticity_config, defaults) {}
    expect(config.index_base_name).to eql("users")
    expect(config.document_type).to eql("user")
  end

  it "overrides defaults" do
    config = described_class.new(elasticity_config, defaults) do |c|
      c.index_base_name = "user_documents"
      c.document_type = "users"
    end

    expect(config.index_base_name).to eql("user_documents")
    expect(config.document_type).to eql("users")
  end

  context "subclass warnings and exceptions" do
    class Multied < Elasticity::Document
    end
    describe "multi_mapping exceptions" do
      it "raises an exception for version 7 and above if subclasses are configured" do
        stub_version("7.0.0")
        expect do
          Multied.configure do |c|
            c.index_base_name = "cats_and_dogs"
            c.strategy = Elasticity::Strategies::SingleIndex
            c.subclasses = { cat: "Cat", dog: "Dog" }
          end
        end.to raise_error(
          Elasticity::IndexConfig::SubclassError,
          Elasticity::IndexConfig::SUBCLASSES_ERROR
        )
      end

      it "does not raise an exception for version 7 and above if no subclasses are configured" do
        stub_version("7.0.0")
        expect do
          Multied.configure do |c|
            c.index_base_name = "cats_and_dogs"
            c.strategy = Elasticity::Strategies::SingleIndex
          end
        end.to_not raise_error
      end
    end

    describe "multi_mapping warnings" do
      it "warns if multi_mapping is not supported by the ES version" do
        stub_version("6.0.2")
        expect do
          Multied.configure do |c|
            c.index_base_name = "cats_and_dogs"
            c.strategy = Elasticity::Strategies::SingleIndex
            c.subclasses = { cat: "Cat", dog: "Dog" }
          end
        end.to output("#{Elasticity::IndexConfig::SUBCLASSES_WARNING}\n").to_stderr
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
    end

    describe "passing the time_stamp option" do
      it "allows passing of a time_stamp_format option" do
        config = described_class.new(elasticity_config, defaults) {}
        expect(config.index_base_name).to eql("users")
        expect(config.document_type).to eql("user")
        expect(config.use_new_timestamp_format).to be_falsy

        config = described_class.new(elasticity_config, defaults) do |c|
          c.index_base_name = "user_documents"
          c.document_type = "users"
          c.use_new_timestamp_format = true
        end

        expect(config.index_base_name).to eql("user_documents")
        expect(config.document_type).to eql("users")
        expect(config.use_new_timestamp_format).to be_truthy
      end
    end

    describe "passing the include_type_name option" do
      it "allows passing of a include_type_name_on_create option" do
        config = described_class.new(elasticity_config, defaults) {}
        expect(config.index_base_name).to eql("users")
        expect(config.document_type).to eql("user")
        expect(config.include_type_name_on_create).to be_falsy

        config = described_class.new(elasticity_config, defaults) do |c|
          c.index_base_name = "user_documents"
          c.document_type = "users"
          c.include_type_name_on_create = true
        end

        expect(config.index_base_name).to eql("user_documents")
        expect(config.document_type).to eql("users")
        expect(config.include_type_name_on_create).to be_truthy
      end
    end

    def stub_version(version)
      allow_any_instance_of(Elasticity::InstrumentedClient).to receive(:versions).and_return([version])
    end
  end
end
