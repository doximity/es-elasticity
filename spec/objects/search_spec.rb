require "elasticity/search"

RSpec.describe Elasticity::Search do
  let(:index)          { double(:index) }
  let(:document_type)  { "document" }
  let(:body)           { {} }

  subject do
    described_class.new(index, "document", body) { |doc| double(doc["_source"]["name"], doc["_source"]) }
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

  it "searches the index and return document instances mapped using the mapper function" do
    expect(index).to receive(:search).with(document_type, body).and_return(full_response)

    docs = subject.documents

    expect(docs.length).to be 2
    expect(docs[0].name).to eq "foo"
    expect(docs[1].name).to eq "bar"
  end

  it "defines basic collection methods" do
    expect(index).to receive(:search).with(document_type, body).and_return(full_response)

    expect(subject.total).to be 2
    expect(subject).to_not be_empty
    expect(subject).to_not be_blank
  end

  it "maps index results to a ActiveRecord relation" do
    expect(index).to receive(:search).with(document_type, body.merge(_source: ["id"])).and_return(ids_response)

    connection = double(:db_connection)
    allow(connection).to receive(:quote_column_name) { |name| name }

    relation = double(:relation, connection: connection, table_name: "table_name")
    expect(relation).to receive(:where).with(id: [1,2]).and_return(relation)
    expect(relation).to receive(:order).with("FIELD(table_name.id,1,2)").and_return(relation)

    expect(subject.database(relation).mapping).to be relation
  end
end
