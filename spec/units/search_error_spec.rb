require "elasticity/search_error"

RSpec.describe Elasticity::SearchError do
  describe ".process" do
    let(:error_400) do
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

    let(:error_500) do
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

    let(:error_unknown) do
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

    it "raises an error for the given status code" do
      expect { described_class.process error_400 }.to(
        raise_error Elasticsearch::Transport::Transport::Errors::BadRequest,
                    error_400.to_json
      )

      expect { described_class.process error_500 }.to(
        raise_error Elasticsearch::Transport::Transport::Errors::InternalServerError,
                    error_500.to_json
      )
    end

    it "raises an unkown error for an known status code" do
      expect { described_class.process error_unknown }.to(
        raise_error Elasticity::SearchError::Unknown, error_unknown.to_json
      )
    end
  end
end
