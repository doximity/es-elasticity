RSpec.describe "Persistence", elasticsearch: true do
  describe "single index strategy" do
    subject do
      Class.new(Elasticity::Document) do
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

        attr_accessor :name, :birthdate

        def to_document
          { name: name, birthdate: birthdate }
        end
      end
    end

    before do
      subject.recreate_index
    end

    after do
      subject.delete_index
    end

    it "successfully index, update, search, count and delete" do
      john = subject.new(name: "John", birthdate: "1985-10-31")
      mari = subject.new(name: "Mari", birthdate: "1986-09-24")

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

  describe "alias index strategy" do
    subject do
      Class.new(Elasticity::Document) do
        configure do |c|
          c.index_base_name = "users"
          c.document_type   = "user"
          c.strategy        =  Elasticity::Strategies::AliasIndex

          c.mapping = {
            properties: {
              name: { type: "string" },
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
    end

    after do
      subject.delete_index
    end

    it "remaps to a different index transparently" do
      john = subject.new(name: "John", birthdate: "1985-10-31")
      mari = subject.new(name: "Mari", birthdate: "1986-09-24")

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
      docs = 2000.times.map do |i|
        subject.new(name: "User #{i}", birthdate: "#{rand(20)+1980}-#{rand(11)+1}-#{rand(28)+1}").tap(&:update)
      end

      t = Thread.new { subject.remap! }

      to_update = docs.sample(10)
      to_delete = (docs - to_update).sample(10)

      to_update.each(&:update)
      to_delete.each(&:delete)

      20.times.map do |i|
        subject.new(name: "User #{i + docs.length}", birthdate: "#{rand(20)+1980}-#{rand(11)+1}-#{rand(28)+1}").tap(&:update)
      end

      t.join

      subject.flush_index
      results = subject.search(sort: :name)
      expect(results.total).to eq(2010)
    end

    it "recover from remap interrupts" do
      docs = 2000.times.map do |i|
        subject.new(name: "User #{i}", birthdate: "#{rand(20)+1980}-#{rand(11)+1}-#{rand(28)+1}").tap(&:update)
      end

      t = Thread.new { subject.remap! }

      to_update = docs.sample(10)
      to_delete = (docs - to_update).sample(10)

      to_update.each(&:update)
      to_delete.each(&:delete)

      20.times.map do |i|
        subject.new(name: "User #{i + docs.length}", birthdate: "#{rand(20)+1980}-#{rand(11)+1}-#{rand(28)+1}").tap(&:update)
      end

      t.raise("Test Interrupt")
      expect { t.join }.to raise_error("Test Interrupt")

      subject.flush_index
      results = subject.search(sort: :name)
      expect(results.total).to eq(2010)
    end
  end
end
