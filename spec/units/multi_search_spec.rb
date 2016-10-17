require "elasticity/search"
require "elasticity/multi_search"

RSpec.describe Elasticity::MultiSearch do
  let :client do
    double(:client)
  end

  let :klass do
    Class.new do
      include ActiveModel::Model
      attr_accessor :_id, :name

      def self.map_hit(hit)
        new(_id: hit["_id"], name: hit["_source"]["name"])
      end

      def ==(other)
        self._id == other._id && self.name == other.name
      end
    end
  end

  let :index_with_one_hit do
    {
      "hits" => {
        "total" => 1,
        "hits" => [
          { "_id" => 3, "_source" => { "name" => "baz" }}
        ]
      }
    }
  end

  let :index_with_two_hits do
    {
      "hits" => {
        "total" => 2,
        "hits" => [
          { "_id" => 1, "_source" => { "name" => "foo" }},
          { "_id" => 2, "_source" => { "name" => "bar" }}
        ]
      }
    }
  end

  let :aggregations do
    {
      "aggregations" => {
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
    }
  end

  let :index_with_two_hits_and_aggregations do
    index_with_two_hits.merge(aggregations)
  end

  let :response do
    {
      "responses" => [
        index_with_two_hits_and_aggregations,
        index_with_one_hit
      ]
    }
  end

  it "performs multi search" do
    subject.add(:first, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_first", "document_first", { search: :first, size: 2 })), documents: klass)
    subject.add(:second, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_second", "document_second", { search: :second })), documents: klass)

    expect(Elasticity.config.client).to receive(:msearch).with(body: [
      { index: "index_first", type: "document_first", search: { search: :first, size: 2 } },
      { index: "index_second", type: "document_second", search: { search: :second } },
    ]).and_return(response)

    expect(Array(subject[:first])).to eq [klass.new(_id: 1, name: "foo"), klass.new(_id: 2, name: "bar")]
    expect(Array(subject[:second])).to eq [klass.new(_id: 3, name: "baz")]
    expect(subject[:first].total).to eq 2
    expect(subject[:first].total_pages).to eq 1
    expect(subject[:first].current_page).to eq 1
    expect(subject[:first].aggregations).to eq aggregations["aggregations"]
    expect(subject[:second].aggregations).to eq Hash.new
  end

  it "performs multi search with additional arguments" do
    msearch = Elasticity::MultiSearch.new(search_type: :dfs_query_then_fetch)
    msearch.add(:first, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_first", "document_first", { search: :first, size: 2 })), documents: klass)
    msearch.add(:second, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_second", "document_second", { search: :second })), documents: klass)

    expect(Elasticity.config.client).to receive(:msearch).with(search_type: :dfs_query_then_fetch, body: [
      { index: "index_first", type: "document_first", search: { search: :first, size: 2 } },
      { index: "index_second", type: "document_second", search: { search: :second } },
    ]).and_return(response)

    expect(Array(msearch[:first])).to eq([klass.new(_id: 1, name: "foo"), klass.new(_id: 2, name: "bar")])
  end
end
