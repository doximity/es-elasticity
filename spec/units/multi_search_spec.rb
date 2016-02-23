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

  let :response do
    {
      "responses" => [
        { "hits" => { "total" => 2, "hits" => [{ "_id" => 1, "_source" => { "name" => "foo" }}, { "_id" => 2, "_source" => { "name" => "bar" }}]}},
        { "hits" => { "total" => 1, "hits" => [{ "_id" => 3, "_source" => { "name" => "baz" }}]}},
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
  end
end
