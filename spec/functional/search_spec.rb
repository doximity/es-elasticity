RSpec.describe "Search", elasticsearch: true do
  class CatDoc < Elasticity::Document
    configure do |c|
      c.strategy = Elasticity::Strategies::SingleIndex
      c.document_type  = "cat"
      c.mapping = { "properties" => {
        name: { type: "text" },
        description: { type: "text" },
        age: { type: "integer" }
      } }
    end

    attr_accessor :name, :age, :description

    def to_document
      { name: name, age: age, description: description }
    end
  end

  class DogDoc < Elasticity::Document
    configure do |c|
      c.strategy = Elasticity::Strategies::SingleIndex
      c.document_type = "dog"
      c.mapping = { "properties" => {
        name: { type: "keyword" },
        description: { type: "text" },
        age: { type: "integer" },
        hungry: { type: "boolean" }
      } }
    end
    attr_accessor :name, :age, :description, :hungry

    def to_document
      { name: name, age: age, description: description, hungry: hungry }
    end
  end

  describe "search_args" do
    before do
      CatDoc.recreate_index
      DogDoc.recreate_index

      @elastic_search_client.cluster.health wait_for_status: "yellow"

      cat = CatDoc.new(name: "felix the cat", age: 10, description: "I am an old cat")
      dog = DogDoc.new(name: "fido", age: 4, hungry: true, description: "I am a hungry dog")

      cat.update
      dog.update

      CatDoc.refresh_index
    end

    describe "explain: true" do
      def get_explanations(results)
        results.map(&:_explanation)
      end

      it "supports on single index search results" do
        results = CatDoc.search({}, { explain: true }).search_results

        expect(get_explanations(results)).to all( be_truthy )
      end

      it "supports for multisearch" do
        cat = CatDoc.search({}, { explain: true })
        dog = DogDoc.search({})

        subject = Elasticity::MultiSearch.new do |m|
          m.add(:cats, cat, documents: CatDoc)
          m.add(:dogs, dog, documents: DogDoc)
        end

        expect(get_explanations(subject[:cats])).to all( be_truthy )
        expect(get_explanations(subject[:dogs])).to all( be_nil )
      end
    end

    describe "matched_queries" do
      it "returns a list of named queries that were matched on the result" do
        query = {
          query: {
            match: {
              description: {
                query: "old",
                _name: "description_query"
              }
            }
          }
        }
        results = CatDoc.search(query).search_results
        expect(results.size).to eq(1)
        result = results.first
        expect(result.matched_queries).to eq(["description_query"])
      end
    end

    describe "highlight" do
      it "is nil when the highlight does not return" do
        results =  CatDoc.search({}).search_results

        expect(results.first.highlighted_attrs).to be_nil
        expect(results.first.highlighted).to be_nil
      end

      describe "when specifying highlight" do
        let(:cat_search_result) {
          highlight_search = {
              query: {
                  multi_match: {
                      query: "cat",
                      fields: ["name^1000", "description"]
                  }
              },
              highlight: {
                  fields: {
                      "*": {}
                  }
              }
          }

          CatDoc.search(highlight_search).search_results.first
        }

        it "highlighted_attrs returns the highlighted" do
          expect(cat_search_result.highlighted_attrs).to eq(["name", "description"])
        end

        it "highlighted returns a new object with the name transformed" do
          expect(cat_search_result.highlighted.name.first).to include("felix")
          expect(cat_search_result.highlighted.description.first).to include("old")
        end
      end
    end
  end
end
