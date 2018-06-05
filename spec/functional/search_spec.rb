RSpec.describe "Search", elasticsearch: true do
  describe "multi mapping index" do
    class Cat < Elasticity::Document
      configure do |c|
        c.index_base_name = "cats"
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

    class Dog < Elasticity::Document
      configure do |c|
        c.index_base_name = "dogs"
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
      before do
        Cat.recreate_index
        Dog.recreate_index

        @elastic_search_client.cluster.health wait_for_status: 'yellow'

        cat = Cat.new(name: "felix", age: 10)
        dog = Dog.new(name: "fido", age: 4, hungry: true)

        cat.update
        dog.update

        Cat.flush_index
      end

      describe "explain: true" do
        def get_explanations(results)
          results.map(&:_explanation)
        end

        it "supports on single search index" do
          results = Cat.search({}, { explain: true }).search_results

          expect(get_explanations(results)).to all( be_truthy )
          # expect(results.first._explanation).to_not be_nil
        end

        it "supports for multisearch" do
          cat = Cat.search({}, { explain: true })
          dog = Dog.search({})

          subject = Elasticity::MultiSearch.new do |m|
            m.add(:cats, cat, documents: Cat)
            m.add(:dogs, dog, documents: Dog)
          end

          expect(get_explanations(subject[:cats])).to all( be_truthy )
          expect(get_explanations(subject[:dogs])).to all( be_nil )
        end
      end
    end
  end
end
