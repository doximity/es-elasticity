RSpec.describe "Search", elasticsearch: true do
  class CatDoc < Elasticity::Document
    configure do |c|
      c.strategy = Elasticity::Strategies::SingleIndex
      c.document_type  = "cat"
      c.mapping = { "properties" => {
        name: { type: "keyword" },
        age: { type: "integer" }
      } }
    end

    attr_accessor :name, :age

    def to_document
      { name: name, age: age }
    end
  end

  class DogDoc < Elasticity::Document
    configure do |c|
      c.strategy = Elasticity::Strategies::SingleIndex
      c.document_type = "dog"
      c.mapping = { "properties" => {
        name: { type: "keyword" },
        age: { type: "integer" },
        hungry: { type: "boolean" }
      } }
    end
    attr_accessor :name, :age, :hungry

    def to_document
      { name: name, age: age, hungry: hungry }
    end
  end

  describe "search_args" do
    let(:cat_name) { "felix" }

    before do
      CatDoc.recreate_index
      DogDoc.recreate_index

      @elastic_search_client.cluster.health wait_for_status: 'yellow'

      cat = CatDoc.new(name: cat_name, age: 10)
      dog = DogDoc.new(name: "fido", age: 4, hungry: true)

      cat.update
      dog.update

      CatDoc.flush_index
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

    describe "highlight" do
      it "is nil when the highlight does not return" do
        results =  CatDoc.search({}).search_results

        expect(results.first.highlight).to be_nil
        expect(results.first.highlighted).to be_nil
      end

      describe "when specifying highlight" do
        let(:cat_search_result) {
          highlight_search = {
              query: {
                  term: {
                      name: cat_name
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

        it "highlight returns the name as a key" do
          expect(cat_search_result.highlight.keys).to eq(["name"])
          expect(cat_search_result.highlight["name"].first).to include(cat_name)
        end

        it "highlighted returns a new object with the name transformed" do
          expect(cat_search_result.highlighted.name.first).to include(cat_name)
        end
      end
    end
  end
end
