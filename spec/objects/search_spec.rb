require "elasticity/search"

RSpec.describe Elasticity::Search do
  let(:index)          { double(:index) }
  let(:document_type)  { "document" }
  let(:body)           { {} }

  subject do
    described_class.new(index, "document", body)
  end

  let :full_response do
    { "hits" => { "total" => 2, "hits" => [
      {"_source" => { "id" => 1, "name" => "foo" }},
      {"_source" => { "id" => 2, "name" => "bar" }},
    ]}}
  end

  let :ids_response do
    { "hits" => { "total" => 2, "hits" => [
      {"_source" => { "id" => 1, "name" => "foo" }},
      {"_source" => { "id" => 2, "name" => "bar" }},
    ]}}
  end

  it "searches the index and return document models" do
    expect(index).to receive(:search).with(document_type, body).and_return(full_response)

    klass = Class.new do
      include ActiveModel::Model
      attr_accessor :id, :name
    end

    docs = subject.documents(klass)

    expect(docs.size).to be 2
    expect(docs[0].name).to eq "foo"
    expect(docs[1].name).to eq "bar"
  end

  it "searches the index and return active record models" do
    expect(index).to receive(:search).with(document_type, body.merge(_source: ["id"])).and_return(ids_response)

    relation = double(:relation,
      connection: double(:connection),
      table_name: "table_name",
      klass: double(:klass, primary_key: "id"),
    )
    allow(relation.connection).to receive(:quote_column_name) { |name| name }

    expect(relation).to receive(:where).with(id: [1,2]).and_return(relation)
    expect(relation).to receive(:order).with("FIELD(table_name.id,1,2)").and_return(relation)

    expect(subject.active_records(relation).mapping).to be relation
  end
end
