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
    expect(subject[:third]).to be_nil
  end

  it "performs multi search with additional arguments" do
    subject = Elasticity::MultiSearch.new(search_type: :dfs_query_then_fetch)
    subject.add(:first, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_first", "document_first", { search: :first, size: 2 })), documents: klass)
    subject.add(:second, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_second", "document_second", { search: :second })), documents: klass)

    expect(Elasticity.config.client).to receive(:msearch).with(search_type: :dfs_query_then_fetch, body: [
      { index: "index_first", type: "document_first", search: { search: :first, size: 2 } },
      { index: "index_second", type: "document_second", search: { search: :second } },
    ]).and_return(response)

    expect(Array(subject[:first])).to eq([klass.new(_id: 1, name: "foo"), klass.new(_id: 2, name: "bar")])
  end

  context "when there was an error for one query" do
    let(:error) do
      {
        "error" => {
          "root_cause" => [
            {
              "type" => "too_many_clauses",
              "reason" => "too_many_clauses: maxClauseCount is set to 1024"
            }
          ],
          "type" => "search_phase_execution_exception",
          "grouped" => true,
        },
        "status" => 400
      }
    end

    let(:response) do
      {
        "responses" => [
          index_with_two_hits_and_aggregations,
          index_with_one_hit,
          error
        ]
      }
    end

    before do
      expect(Elasticity.config.client).to receive(:msearch).with(body: [
        { index: "index_first", type: "document_first", search: { search: :first, size: 2 } },
        { index: "index_second", type: "document_second", search: { search: :second } },
        { index: "index_third", type: "document_third", search: { search: :third } },
      ]).and_return(response)
    end

    it "raises an error while trying to access the query result" do
      subject.add(:first, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_first", "document_first", { search: :first, size: 2 })), documents: klass)
      subject.add(:second, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_second", "document_second", { search: :second })), documents: klass)
      subject.add(:third, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_third", "document_third", { search: :third })), documents: klass)

      expect(Array(subject[:first])).to eq [klass.new(_id: 1, name: "foo"), klass.new(_id: 2, name: "bar")]
      expect { subject[:third] }.to raise_error Elasticsearch::Transport::Transport::Errors::BadRequest, error.to_json
    end

    context "skipping raising of error" do
      before do
        @subject = Elasticity::MultiSearch.new(skip_raise_on_errors: true)
        @subject.add(:first, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_first", "document_first", { search: :first, size: 2 })), documents: klass)
        @subject.add(:second, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_second", "document_second", { search: :second })), documents: klass)
        @subject.add(:third, Elasticity::Search::Facade.new(client, Elasticity::Search::Definition.new("index_third", "document_third", { search: :third })), documents: klass)
      end

      it "skips raising an error while trying to access the query result if so directed" do
        expect(Array(@subject[:first])).to eq [klass.new(_id: 1, name: "foo"), klass.new(_id: 2, name: "bar")]
        expect(@subject[:third].error).to eq(error["error"])
      end

      it "knows which elements of the results are valid" do
        expect(@subject[:first].valid?).to be true
        expect(@subject[:second].valid?).to be true
        expect(@subject[:third].valid?).to be false
      end
    end
  end
end
