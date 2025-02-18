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

  let :full_response_v7 do
    { "hits" => { "total" => { "value" => 2, "relation" => "eq" }, "hits" => [
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
    { "_scroll_id" => "abc123", "hits" => { "total" => 2, "hits" => [
      { "_id" => 1, "_source" => { "name" => "foo" } }
    ]}}
  end

  let :scroll_response do
    { "_scroll_id" => "abc456", "hits" => { "total" => 1, "hits" => [
      { "_id" => 2, "_source" => { "name" => "bar" } },
    ]}}
  end

  let :mapper do
    -> (hit) {
      klass.new(_id: hit["_id"], name: hit["_source"]["name"], age: hit["_source"]["age"])
    }
  end

  let :klass do
    Class.new do
      include ActiveModel::Model
      attr_accessor :_id, :name, :age

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
      expect(client).to receive(:search).
        with(hash_including(index: index_name, body: body)).
        and_return(full_response)

      docs = subject.documents(mapper)
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

    it "handles the v7 'total' response object" do
      expect(client).to receive(:search).
        with(hash_including(index: index_name, body: body)).
        and_return(full_response_v7)

      docs = subject.documents(mapper)
      expect(docs.total).to eq 2

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
      expect(client).to receive(:search).
        with(hash_including(index: index_name, body: body)).
        and_return(full_response_with_aggregations)

      docs = subject.documents(mapper)
      expect(docs.aggregations).to eq aggregations
    end

    it "searches using scan&scroll" do
      expect(client).to receive(:search).
        with(hash_including(index: index_name, body: body, search_type: :query_then_fetch, size: 100, scroll: "1m")).and_return(scan_response)
      expect(client).to receive(:scroll).
        with(hash_including(scroll_id: "abc123", scroll: "1m", body: { scroll_id: "abc123" })).and_return(scroll_response)
      expect(client).to receive(:scroll).
        with(hash_including(scroll_id: "abc456", scroll: "1m", body: { scroll_id: "abc456" })).and_return(empty_response)

      docs = subject.scan_documents(mapper)
      expected = [klass.new(_id: 1, name: "foo"), klass.new(_id: 2, name: "bar")]

      expect(docs.total).to eq 2

      expect(docs).to_not be_empty
      expect(docs).to_not be_blank

      expect(Array(docs)).to eq expected
    end

    it "searches the index and return active record models" do
      expect(client).to receive(:search).
        with(hash_including(index: index_name, body: body.merge(_source: false))).
        and_return(ids_response)

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
      expect(client).to receive(:search).with(hash_including(index: index_name, body: body)).and_return(full_response)
      docs = subject.documents(mapper)

      expect(docs.per_page).to eq(10)
      expect(docs.total_pages).to eq(1)
      expect(docs.current_page).to eq(1)
      expect(docs.next_page).to eq(nil)
      expect(docs.previous_page).to eq(nil)
    end

    it "provides custom properties for pagination" do
      subject = Elasticity::Search::Facade.new(
        client,
        Elasticity::Search::Definition.new(
          index_name,
          document_type,
          { size: 15, from: 15, filter: {} }
        )
      )
      expect(client).to receive(:search).
        with(
          hash_including(
            index: index_name,
            body: { size: 15, from: 15, filter: {} }
          )
        ).and_return({ "hits" => { "total" => 112, "hits" => [] } })
      docs = subject.documents(mapper)

      expect(docs.per_page).to eq(15)
      expect(docs.total_pages).to eq(8)
      expect(docs.current_page).to eq(2)
      expect(docs.next_page).to eq(3)
      expect(docs.previous_page).to eq(1)
    end

    it "merges in additional arguments for search" do
      results = double(:results, :[] => { "hits" => [] })
      subject = Elasticity::Search::Facade.new(
        client,
        Elasticity::Search::Definition.new(index_name, document_type, {})
      )

      expect(client).to receive(:search).with(
        hash_including(
          index: index_name,
          body: {},
          search_type: :dfs_query_and_fetch
        )
      ).and_return(results)
      subject.documents(mapper, search_type: :dfs_query_and_fetch).search_results
    end
  end

  describe Elasticity::Search::DocumentProxy do
    let :search do
      Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new(index_name, "document", body))
    end

    subject do
      described_class.new(search, mapper)
    end

    it "automatically maps the documents into the provided Document class" do
      expect(client).to receive(:search).
        with(hash_including(index: index_name, body: body)).
        and_return(full_response)
      expect(Array(subject)).to eq [klass.new(_id: 1, name: "foo"), klass.new(_id: 2, name: "bar")]
    end

    it "delegates active_records for the underlying search" do
      records = double(:records)
      rel     = double(:relation)
      expect(search).to receive(:active_records).with(rel).and_return(records)
      expect(subject.active_records(rel)).to be records
    end

    it "accepts additional arguments for a search" do
      results = double(:results)

      expect(search).to receive(:documents).with(mapper, hash_including(search_type: :dfs_query_then_fetch)).and_return(results)
      expect(subject.documents(search_type: :dfs_query_then_fetch)).to eq(results)
    end

  end
end
