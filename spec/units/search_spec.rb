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

  let :aggregations do
    {
      "logins_count" => { "value" => 1495 },
      "gender" => {
          "buckets" => [
              {
                  "doc_count" => 100,
                  "key" => "M"
              },
              {
                  "doc_count" => 100,
                  "key" => "F"
              }
          ],
          "doc_count_error_upper_bound" => 0,
          "sum_other_doc_count" => 0
      }
    }
  end

  let :full_response_with_aggregations do
    full_response.merge("aggregations" => aggregations)
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

  let :scan_response do
    { "_scroll_id" => "abc123", "hits" => { "total" => 2 } }
  end

  let :scroll_response do
    { "_scroll_id" => "abc456", "hits" => { "total" => 2, "hits" => [
      { "_id" => 1, "_source" => { "name" => "foo" } },
      { "_id" => 2, "_source" => { "name" => "bar" } },
    ]}}
  end

  let :klass do
    Class.new do
      include ActiveModel::Model
      attr_accessor :_id, :name, :age

      def self.from_hit(hit)
        new(_id: hit["_id"], name: hit["_source"]["name"], age: hit["_source"]["age"])
      end

      def ==(other)
        self._id == other._id && self.name == other.name
      end
    end
  end

  describe Elasticity::Search::Facade do
    subject do
      described_class.new(client, Elasticity::Search::Definition.new(index_name, document_type, body))
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

    it "searches and the index returns aggregations" do
      expect(client).to receive(:search).with(index: index_name, type: document_type, body: body).and_return(full_response_with_aggregations)

      docs = subject.documents(klass)
      expect(docs.aggregations).to eq aggregations
    end

    it "searches using scan&scroll" do
      expect(client).to receive(:search).with(index: index_name, type: document_type, body: body, search_type: "scan", size: 100, scroll: "1m").and_return(scan_response)
      expect(client).to receive(:scroll).with(scroll_id: "abc123", scroll: "1m").and_return(scroll_response)
      expect(client).to receive(:scroll).with(scroll_id: "abc456", scroll: "1m").and_return(empty_response)

      docs = subject.scan_documents(klass)
      expected = [klass.new(_id: 1, name: "foo"), klass.new(_id: 2, name: "bar")]

      expect(docs.total).to eq 2

      expect(docs).to_not be_empty
      expect(docs).to_not be_blank

      expect(Array(docs)).to eq expected
    end

    it "searches the index and return active record models" do
      expect(client).to receive(:search).with(index: index_name, type: document_type, body: body.merge(_source: false)).and_return(ids_response)

      relation = double(:relation,
        connection: double(:connection),
        table_name: "table_name",
        klass: double(:klass, primary_key: "id"),
        to_sql: "SELECT * FROM table_name WHERE id IN (1)"
      )
      allow(relation.connection).to receive(:quote_column_name) { |name| name }
      allow(relation.connection).to receive(:quote) { |name| name }

      expect(relation).to receive(:where).with("table_name.id IN (?)", [1, 2]).and_return(relation)
      expect(relation).to receive(:order).with("FIELD(table_name.id, 1,2)").and_return(relation)

      expect(subject.active_records(relation).to_sql).to eq "SELECT * FROM table_name WHERE id IN (1)"
    end
  end

  describe Elasticity::Search::LazySearch do
    it "provides defaul properties for pagination" do
      subject = Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new(index_name, document_type, body))
      expect(client).to receive(:search).with(index: index_name, type: document_type, body: body).and_return(full_response)
      docs = subject.documents(klass)

      expect(docs.per_page).to eq(10)
      expect(docs.total_pages).to eq(1)
      expect(docs.current_page).to eq(1)
    end

    it "provides custom properties for pagination" do
      subject = Elasticity::Search::Facade.new(
        client,
        Elasticity::Search::Definition.new(
          index_name,
          document_type,
          { size: 14, from: 25, filter: {} }
        )
      )
      expect(client).to receive(:search).
        with(
          index: index_name,
          type: document_type,
          body: { size: 14, from: 25, filter: {} }
        ).and_return({ "hits" => { "total" => 112 } })
      docs = subject.documents(klass)

      expect(docs.per_page).to eq(14)
      expect(docs.total_pages).to eq(8)
      expect(docs.current_page).to eq(2)
    end
  end

  describe Elasticity::Search::DocumentProxy do
    let :search do
      Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new(index_name, "document", body))
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
