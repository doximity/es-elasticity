RSpec.describe "Persistence", elasticsearch: true do
  describe "single index strategy" do
    subject do
      Class.new(Elasticity::Document) do
        elasticity_attributes :name, :birthdate

        def self.name
          'SomeClass'
        end

        configure do |c|
          c.index_base_name = "users"
          c.document_type   = "user"
          c.strategy        = Elasticity::Strategies::SingleIndex

          c.mapping = {
            properties: {
              name: { type: "string" },
              birthdate: { type: "date" },
            },
          }
        end
      end
    end

    before do
      subject.recreate_index
      @elastic_search_client.cluster.health wait_for_status: 'yellow'
    end

    after do
      subject.delete_index
    end

    it "counts empty search" do
      count = subject.search({}).count
      expect(count).to eq 0
    end

    it "successfully index, update, search, count and delete" do
      john = subject.new(name: "John", birthdate: "1985-10-31", sort: ['john'])
      mari = subject.new(name: "Mari", birthdate: "1986-09-24", sort: ['mari'])

      john.update
      mari.update

      subject.flush_index

      results = subject.search(sort: :name)
      expect(results.total).to eq 2

      expect(results[0]).to eq(john)
      expect(results[1]).to eq(mari)

      expect(subject.search({query: {filtered: { query: { match_all: {} } } } }).count).to eq(2)

      john.update
      mari.delete

      subject.flush_index

      results = subject.search(sort: :name)
      expect(results.total).to eq 1

      expect(results[0]).to eq(john)
    end
  end

  describe 'multi mapping index' do
    class Animal < Elasticity::Document
      configure do |c|
        c.index_base_name = "cats_and_dogs"
        c.strategy = Elasticity::Strategies::SingleIndex
        c.subclasses = { cat: "Cat", dog: "Dog" }
      end
    end

    class Cat < Animal
      elasticity_attributes :name, :age

      configure do |c|
        c.index_base_name = "cats_and_dogs"
        c.strategy = Elasticity::Strategies::SingleIndex
        c.document_type  = "cat"
        c.mapping = { properties: {
          name: { type: "string" },
          age: { type: "integer" }
        } }
      end
    end

    class Dog < Animal
      elasticity_attributes :name, :age, :hungry

      configure do |c|
        c.index_base_name = "cats_and_dogs"
        c.strategy = Elasticity::Strategies::SingleIndex
        c.document_type = "dog"
        c.mapping = { properties: {
          name: { type: "string" },
          age: { type: "integer" },
          hungry: { type: "boolean" }
        } }
      end
    end

    before do
      Animal.recreate_index
      @elastic_search_client.cluster.health wait_for_status: 'yellow'
    end

    it "successful index, update, search, count and deletes" do
      cat = Cat.new(name: "felix", age: 10)
      dog = Dog.new(name: "fido", age: 4, hungry: true)

      cat.update
      dog.update

      Animal.flush_index

      results = Animal.search({})
      expect(results.total).to eq 2
      expect(results.map(&:class)).to include(Cat, Dog)

      results = Cat.search({})
      expect(results.total).to eq 1
      expect(results.first.class).to eq Cat

      results = Dog.search({})
      expect(results.total).to eq 1
      expect(results.first.class).to eq Dog

      cat.delete
      Animal.flush_index

      results = Animal.search({})
      expect(results.total).to eq 1
      expect(results.map(&:class)).to include(Dog)
    end
  end

  describe "alias index strategy" do
    subject do


      Class.new(Elasticity::Document) do
        elasticity_attributes :id, :name, :birthdate

        def self.name
          "SomeClass"
        end

        configure do |c|
          c.index_base_name = "users"
          c.document_type   = "user"
          c.strategy        =  Elasticity::Strategies::AliasIndex

          c.mapping = {
            _id: { path: "id" },
            properties: {
              id: { type: "integer" },
              name: { type: "string" },
              birthdate: { type: "date" },
            },
          }
        end
      end
    end

    before do
      subject.recreate_index
    end

    after do
      subject.delete_index
    end

    it "counts empty search" do
      count = subject.search({}).count
      expect(count).to eq 0
    end

    it "remaps to a different index transparently" do
      john = subject.new(id: 1, name: "John", birthdate: "1985-10-31", sort: ['john'])
      mari = subject.new(id: 2, name: "Mari", birthdate: "1986-09-24", sort: ['mari'])

      john.update
      mari.update

      subject.flush_index

      results = subject.search(sort: :name)
      expect(results.total).to eq 2

      subject.remap!

      john.update
      mari.delete

      subject.flush_index

      results = subject.search(sort: :name)
      expect(results.total).to eq 1

      expect(results[0]).to eq(john)
    end

    it "handles in between state while remapping" do
      number_of_docs = 2000
      docs = number_of_docs.times.map do |i|
        subject.new(id: i, name: "User #{i}", birthdate: "#{rand(20)+1980}-#{rand(11)+1}-#{rand(28)+1}").tap(&:update)
      end

      t = Thread.new { subject.remap! }

      to_update = docs.sample(10)
      to_delete = (docs - to_update).sample(10)

      to_update.each(&:update)
      to_delete.each(&:delete)

      20.times.map do |i|
        subject.new(id: i + number_of_docs, name: "User #{i + docs.length}", birthdate: "#{rand(20)+1980}-#{rand(11)+1}-#{rand(28)+1}").tap(&:update)
      end

      t.join

      subject.flush_index
      results = subject.search(sort: :name)
      expect(results.total).to eq(2010)
    end

    it "recover from remap interrupts" do
      number_of_docs = 2000
      docs = number_of_docs.times.map do |i|
        subject.new(id: i, name: "User #{i}", birthdate: "#{rand(20)+1980}-#{rand(11)+1}-#{rand(28)+1}").tap(&:update)
      end

      t = Thread.new { subject.remap! }

      to_update = docs.sample(10)
      to_delete = (docs - to_update).sample(10)

      to_update.each(&:update)
      to_delete.each(&:delete)

      20.times.map do |i|
        subject.new(id: i + number_of_docs, name: "User #{i + docs.length}", birthdate: "#{rand(20)+1980}-#{rand(11)+1}-#{rand(28)+1}").tap(&:update)
      end

      t.raise("Test Interrupt")
      expect { t.join }.to raise_error("Test Interrupt")

      subject.flush_index
      results = subject.search(sort: :name)
      expect(results.total).to eq(2010)
    end

    it "bulk indexes, updates and delete" do
      docs = 2000.times.map do |i|
        subject.new(id: i, name: "User #{i}", birthdate: "#{rand(20)+1980}-#{rand(11)+1}-#{rand(28)+1}").tap(&:update)
      end

      subject.bulk_index(docs)
      subject.flush_index

      results = subject.search(from: 0, size: 3000)
      expect(results.total).to eq 2000

      docs = 2000.times.map do |i|
        { _id: i, attr_name: "name", attr_value: "Updated" }
      end

      subject.bulk_update(docs)
      subject.flush_index

      results = subject.search(from: 0, size: 3000)
      expect(results.total).to eq 2000

      expect(subject.search({ query: { match: { name: "Updated" } } } ).count).to eq(2000)

      subject.bulk_delete(results.documents.map(&:_id))
      subject.flush_index

      results = subject.search(from: 0, size: 3000)
      expect(results.total).to eq 0
    end
  end
end
