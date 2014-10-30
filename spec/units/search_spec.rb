require "elasticity/search"

RSpec.describe "Search" do
  let(:client)         { double(:client) }
  let(:index_name)     { "index_name" }
  let(:document_type)  { "document" }
  let(:body)           { {} }

  let :full_response do
    { "hits" => { "total" => 2, "hits" => [
      { "_id" => 1, "_source" => { "name" => "foo" } },
      { "_id" => 2, "_source" => { "name" => "bar" } },
    ]}}
  end

  let :ids_response do
    { "hits" => { "total" => 2, "hits" => [
      { "_id" => 1 },
      { "_id" => 2 },
    ]}}
  end

  let :empty_response do
    { "hits" => { "total" => 0, "hits" => [] }}
  end

  let :highlight_response do
    { "hits" => { "total" => 1, "hits" => [
      { "_id" => 1, "_source" => { "name" => "foo", "age" => 21 }, "highlight" => { "name" => "<em>foo</em>" } },
    ]}}
  end

  let :klass do
    Class.new do
      include ActiveModel::Model
      attr_accessor :_id, :name, :age, :highlighted

      def ==(other)
        self._id == other._id && self.name == other.name
      end
    end
  end

  describe Elasticity::Search do
    subject do
      described_class.new(client, index_name, document_type, body)
    end

    it "searches the index and return document models" do
      expect(client).to receive(:search).with(index: index_name, type: document_type, body: body).and_return(full_response)

      docs = subject.documents(klass)
      expected = [klass.new(_id: 1, name: "foo"), klass.new(_id: 2, name: "bar")]

      expect(docs.total).to eq 2
      expect(docs.size).to eq expected.size

      expect(docs).to_not be_empty
      expect(docs).to_not be_blank

      expect(docs[0].name).to eq expected[0].name
      expect(docs[1].name).to eq expected[1].name

      expect(docs.each.first).to eq expected[0]
      expect(Array(docs)).to eq expected
    end

    it "searches the index and return active record models" do
      expect(client).to receive(:search).with(index: index_name, type: document_type, body: body.merge(_source: false)).and_return(ids_response)

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

    it "return relation.none from activerecord relation with no matches" do
      expect(client).to receive(:search).with(index: index_name, type: document_type, body: body.merge(_source: false)).and_return(empty_response)

      relation = double(:relation)
      expect(relation).to receive(:none).and_return(relation)

      expect(subject.active_records(relation).mapping).to be relation
    end

    it "creates highlighted object for documents" do
      expect(client).to receive(:search).with(index: index_name, type: document_type, body: body).and_return(highlight_response)
      doc = subject.documents(klass).first

      expect(doc).to_not be_nil
      expect(doc.highlighted).to eq klass.new(_id: 1, name: "<em>foo</em>", age: 21)
    end
  end

  describe Elasticity::DocumentSearchProxy do
    let :search do
      Elasticity::Search.new(client, index_name, "document", body)
    end

    subject do
      described_class.new(search, klass)
    end

    it "automatically maps the documents into the provided Document class" do
      expect(client).to receive(:search).with(index: index_name, type: document_type, body: body).and_return(full_response)
      expect(Array(subject)).to eq [klass.new(_id: 1, name: "foo"), klass.new(_id: 2, name: "bar")]
    end

    it "delegates active_records for the underlying search" do
      records = double(:records)
      rel     = double(:relation)
      expect(search).to receive(:active_records).with(rel).and_return(records)
      expect(subject.active_records(rel)).to be records
    end
  end
end
