require "elasticity/search"
require "elasticity/multi_search"

RSpec.describe Elasticity::MultiSearch do
  let :klass do
    Class.new do
      include ActiveModel::Model
      attr_accessor :id, :name

      def ==(other)
        self.id == other.id && self.name == other.name
      end
    end
  end

  let :response do
    {
      "responses" => [
        { "hits" => { "total" => 2, "hits" => [{"_source" => { "id" => 1, "name" => "foo" }}, {"_source" => { "id" => 2, "name" => "bar" }}]}},
        { "hits" => { "total" => 1, "hits" => [{"_source" => { "id" => 3, "name" => "baz" }}]}},
      ]
    }
  end

  it "performs multi search" do
    subject.add(:first, Elasticity::Search.new(double(:index, name: "index_first"), "document_first", { search: :first }), documents: klass)
    subject.add(:second, Elasticity::Search.new(double(:index, name: "index_second"), "document_second", { search: :second }), documents: klass)

    expect(Elasticity.config.client).to receive(:msearch).with(body: [
      { index: "index_first", type: "document_first", body: { search: :first } },
      { index: "index_second", type: "document_second", body: { search: :second } },
    ]).and_return(response)

    expect(Array(subject[:first])). to eq [klass.new(id: 1, name: "foo"), klass.new(id: 2, name: "bar")]
    expect(Array(subject[:second])). to eq [klass.new(id: 3, name: "baz")]
  end
end
