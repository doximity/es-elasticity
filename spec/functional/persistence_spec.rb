RSpec.describe "Persistence", elasticsearch: true do
  def random_birthdate
    Time.at(0.0 + rand * (Time.now.to_f - 0.0.to_f))
  end

  describe "single index strategy" do
    subject do
      Class.new(Elasticity::Document) do
        def self.name
          'SomeClass'
        end

        configure do |c|
          c.index_base_name = "users"
          c.document_type   = "user"
          c.strategy        = Elasticity::Strategies::SingleIndex

          c.mapping = {
            "properties" => {
              name: { type: "text", index: false },
              birthdate: { type: "date" },
            },
          }
        end

        attr_accessor :name, :birthdate

        def to_document
          { name: name, birthdate: birthdate }
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

      results = subject.search({})
      expect(results.total).to eq 2

      expect(subject.search({ query: { match_all: {} } }).count).to eq(2)

      john.update
      mari.delete

      subject.flush_index

      results = subject.search({})
      expect(results.total).to eq 1

      expect(results[0].name).to eq(john.name)
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
      configure do |c|
        c.index_base_name = "cats_and_dogs"
        c.strategy = Elasticity::Strategies::SingleIndex
        c.document_type  = "cat"

        c.mapping = { "properties" => {
          name: { type: "text", index: true },
          age: { type: "integer" }
        } }
      end

      attr_accessor :name, :age

      def to_document
        { name: name, age: age }
      end
    end

    class Dog < Animal
      configure do |c|
        c.index_base_name = "cats_and_dogs"
        c.strategy = Elasticity::Strategies::SingleIndex
        c.document_type = "dog"
        c.mapping = { "properties" => {
          name: { type: "text", index: true },
          age: { type: "integer" },
          hungry: { type: "boolean" }
        } }
      end
      attr_accessor :name, :age, :hungry

      def to_document
        { name: name, age: age, hungry: hungry }
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
      expect(results.scan_documents.count).to eq(1)
    end
  end

  describe "alias index strategy" do
    subject do
      Class.new(Elasticity::Document) do
        def self.name
          "SomeClass"
        end

        configure do |c|
          c.index_base_name = "users"
          c.document_type   = "user"
          c.strategy        =  Elasticity::Strategies::AliasIndex

          c.mapping = {
            "properties" => {
              id: { type: "integer" },
              name: { type: "text", index: true },
              birthdate: { type: "date" },
            },
          }
        end

        attr_accessor :id, :name, :birthdate

        def to_document
          { id: id, name: name, birthdate: birthdate }
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
      john = subject.new(_id: 1, id: 1, name: "John", birthdate: "1985-10-31", sort: ['john'])
      mari = subject.new(_id: 2, id: 2, name: "Mari", birthdate: "1986-09-24", sort: ['mari'])

      john.update
      mari.update

      subject.flush_index
      results = subject.search({})
      expect(results.total).to eq 2

      subject.remap!

      john.update
      mari.delete

      subject.flush_index

      results = subject.search({})
      expect(results.total).to eq 1

      expect(results[0].name).to eq(john.name)
    end

    it "handles in between state while remapping" do
      number_of_docs = 2000
      docs = number_of_docs.times.map do |i|
        subject.new(id: i, name: "User #{i}", birthdate: random_birthdate).tap(&:update)
      end

      t = Thread.new { subject.remap! }

      to_update = docs.sample(10)
      to_delete = (docs - to_update).sample(10)

      to_update.each(&:update)
      to_delete.each(&:delete)

      20.times.map do |i|
        subject.new(id: i + number_of_docs, name: "User #{i + docs.length}", birthdate: random_birthdate).tap(&:update)
      end

      t.join

      subject.flush_index
      results = subject.search({})
      expect(results.total).to eq(2010)
    end

    it "does not copy over fields not defined in the mapping" do
      john = subject.new(_id: 1, id: 1, name: "John", birthdate: "1985-10-31", sort: ['john'])
      mari = subject.new(_id: 2, id: 2, name: "Mari", birthdate: "1986-09-24", sort: ['mari'])

      john.update
      mari.update

      subject.flush_index
      results = subject.search({})
      expect(results.first.birthdate).to be

      # no birthdate
      subject = Class.new(Elasticity::Document) do
        def self.name
          "SomeClass"
        end

        configure do |c|
          c.index_base_name = "users"
          c.document_type   = "user"
          c.strategy        =  Elasticity::Strategies::AliasIndex

          c.mapping = {
            "properties" => {
              id: { type: "integer" },
              name: { type: "text", index: true },
            },
          }
        end

        attr_accessor :id, :name

        def to_document
          { id: id, name: name }
        end
      end

      subject.remap!
      subject.flush_index

      results = subject.search({})
      expect(results.first.respond_to?(:birthdate)).to be false
    end

    it "recover from remap interrupts" do
      number_of_docs = 2000
      docs = number_of_docs.times.map do |i|
        subject.new(id: i, name: "User #{i}", birthdate: random_birthdate).tap(&:update)
      end

      t = Thread.new { subject.remap! }

      to_update = docs.sample(10)
      to_delete = (docs - to_update).sample(10)

      to_update.each(&:update)
      to_delete.each(&:delete)

      20.times.map do |i|
        subject.new(id: i + number_of_docs, name: "User #{i + docs.length}", birthdate: random_birthdate).tap(&:update)
      end

      t.raise("Test Interrupt")
      expect { t.join }.to raise_error("Test Interrupt")

      subject.flush_index
      results = subject.search({})
      expect(results.total).to eq(2010)
    end

    it "fully cleans up if error occurs deleting the old index during remap" do
      expected_aliases = %w[elasticity_test_users elasticity_test_users_update]
      original_aliases = all_aliases(subject)
      expect(original_aliases).to match_array(expected_aliases)
      number_of_docs = 20
      number_of_docs.times.map do |i|
        subject.new(id: i, name: "User #{i}", birthdate: random_birthdate).tap(&:update)
      end

      allow_any_instance_of(Elasticity::InstrumentedClient).to receive(:index_delete).and_raise("KAPOW")
      expect do
        subject.remap!
      end.to raise_error("KAPOW")
      cleaned_up_aliases = all_aliases(subject)
      expect(cleaned_up_aliases).to match_array(expected_aliases)
      allow_any_instance_of(Elasticity::InstrumentedClient).to receive(:index_delete).and_call_original
    end

    context "recovering from remap errors" do
      let(:recoverable_message) do
        '[400] {"error":{"root_cause":[{"type":"remote_transport_exception","reason":"[your_cluster][cluster_id][indices:admin/delete]"}],"type":"illegal_argument_exception","reason":"Cannot delete indices that are being snapshotted: [[full_index_name_and_id]]. Try again after snapshot finishes or cancel the currently running snapshot."},"status":400}'
      end
      after do
        allow_any_instance_of(Elasticity::InstrumentedClient).to receive(:index_delete).and_call_original
      end

      it "waits for recoverable errors before deleting old index during remap" do
        original_index_name = subject.config.client.index_get_alias(index: "#{subject.ref_index_name}-*", name: subject.ref_index_name).keys.first

        call_count = 0
        allow_any_instance_of(Elasticity::InstrumentedClient).to receive(:index_delete) do
          call_count +=1
          if call_count < 3
            raise Elasticsearch::Transport::Transport::Errors::BadRequest.new(recoverable_message)
          else
            []
          end
        end
        build_some_docs(subject)

        subject.remap!(retry_on_recoverable_errors: true, retry_delay: 0.5, max_delay: 1)
        subject.flush_index
        results = subject.search({})
        expect(results.total).to eq(20)
        remapped_index_name = subject.config.client.index_get_alias(index: "#{subject.ref_index_name}-*", name: subject.ref_index_name).keys.first
        expect(remapped_index_name).to_not eq(original_index_name)
      end

      it "will only retry for a set amount of time" do
        allow_any_instance_of(Elasticity::InstrumentedClient).to receive(:index_delete).and_raise(
          Elasticsearch::Transport::Transport::Errors::BadRequest.new(recoverable_message)
        )
        build_some_docs(subject)
        expect {
          subject.remap!(retry_on_recoverable_errors: true, retry_delay: 0.5, max_delay: 1)
        }.to raise_error(Elasticsearch::Transport::Transport::ServerError)
      end

      it "will not only retry if the arguments say not to" do
        original_index_name = subject.config.client.index_get_alias(index: "#{subject.ref_index_name}-*", name: subject.ref_index_name).keys.first
        allow_any_instance_of(Elasticity::InstrumentedClient).to receive(:index_delete).with(any_args).and_call_original
        allow_any_instance_of(Elasticity::InstrumentedClient).to receive(:index_delete).with(index: original_index_name).and_raise(
          Elasticsearch::Transport::Transport::Errors::BadRequest.new(recoverable_message)
        )
        build_some_docs(subject)
        expect {
          subject.remap!(retry_on_recoverable_errors: false)
        }.to raise_error(Elasticsearch::Transport::Transport::ServerError)
      end

      it "will not retry for 'non-recoverable' errors" do
        exception_message = '[404] {"error":"alias [some_index_name] missing","status":404}'
        allow_any_instance_of(Elasticity::InstrumentedClient).to receive(:index_delete).and_raise(
          Elasticsearch::Transport::Transport::Errors::BadRequest.new(exception_message)
        )
        build_some_docs(subject)
        expect {
          subject.remap!(retry_on_recoverable_errors: true, retry_delay: 0.5, max_delay: 1)
        }.to raise_error(Elasticsearch::Transport::Transport::ServerError)
      end
    end

    it "bulk indexes, updates and delete" do
      docs = 2000.times.map do |i|
        subject.new(_id: i, id: i, name: "User #{i}", birthdate: random_birthdate).tap(&:update)
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

  def all_aliases(subj)
    base_name = subj.ref_index_name
    subj.config.client.index_get_alias(index: "#{base_name}-*", name: "#{base_name}*").values.first["aliases"].keys
  end

  def build_some_docs(subj, doc_count = 20)
    doc_count.times.map do |i|
      subj.new(id: i, name: "User #{i}", birthdate: random_birthdate).tap(&:update)
    end
  end
end
