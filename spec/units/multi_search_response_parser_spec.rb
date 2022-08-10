# frozen_string_literal: true

require "elasticity/multi_search_response_parser"

RSpec.describe Elasticity::MultiSearchResponseParser do
  describe ".parse" do
    let :response do
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

    let :search do
      body = {
        index: "index_first",
        type: "document_first",
        search: { search: :first, size: 2 }
      }

      {
        search_definition: OpenStruct.new(body: body),
        documents: klass
      }
    end

    it "parses a simple reponse" do
      search_result = described_class.parse(response, search)

      expect(search_result[0].name).to eq "foo"
      expect(search_result[1].name).to eq "bar"
    end

    context "for a 400 error response" do
      let(:response) do
        {
          "error" => {
            "root_cause" => [
              {
                "type" => "too_many_clauses",
                "reason" => "too_many_clauses: maxClauseCount is set to 1024"
              }
            ],
          },
          "status" => 400
        }
      end

      it "raises an error for the given status code" do
        expect { described_class.parse response, search }.to(
          raise_error Elasticsearch::Transport::Transport::Errors::BadRequest,
                      response.to_json
        )
      end
    end

    context "for a 500 error response" do
      let(:response) do
        {
          "error" => {
            "root_cause" => [
              {
                "type" => "not_index_found",
                "reason" => "not_index_found: index bla was not found"
              }
            ],
          },
          "status" => 500
        }
      end

      it "raises an error for the given status code" do
        expect { described_class.parse response, search }.to(
          raise_error Elasticsearch::Transport::Transport::Errors::InternalServerError,
                      response.to_json
        )
      end
    end

    context "for an unknown error response" do
      let(:response) do
        {
          "error" => {
            "root_cause" => [
              {
                "type" => "known_error",
                "reason" => "known_error: Something wrong happened"
              }
            ],
          },
          "status" => 555
        }
      end

      it "raises an unkown error for an known status code" do
        expect { described_class.parse response, search }.to(
          raise_error Elasticity::MultiSearchResponseParser::UnknownError,
                      response.to_json
        )
      end
    end
  end
end
