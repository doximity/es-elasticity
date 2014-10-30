RSpec.describe "Persistence", elasticsearch: true do
  subject do
    Class.new(Elasticity::Document) do
      self.index_name    = "users"
      self.document_type = "user"
      
      attr_accessor :name, :birthdate

      self.mappings = {
        properties: {
          name: { type: "string" },
          birthdate: { type: "date" },
        },
      }      

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

  describe "simple, one-index" do
    it "successfully index, update, search and delete" do
      john = subject.new(name: "John", birthdate: "1985-10-31")
      mari = subject.new(name: "Mari", birthdate: "1986-09-24")

      john.update
      mari.update

      subject.flush_index

      results = subject.search(sort: :name)
      expect(results.total).to eq 2

      expect(results[0]).to eq(john)
      expect(results[1]).to eq(mari)

      john.update
      mari.delete

      subject.flush_index

      results = subject.search(sort: :name)
      expect(results.total).to eq 1

      expect(results[0]).to eq(john)
    end
  end

  describe "live remap" do
    before do
      subject.class_eval do
        include Elasticity::LiveRemap
        self.redis = Redis.new
      end
    end

    before do
      subject.abort_remap!
    end

    after do
      subject.abort_remap!
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
      expect(subject).to_not be_remapping

      results = subject.search(sort: :name)
      expect(results.total).to eq 1

      expect(results[0]).to eq(john)
    end

    it "handles in between state while remapping" do
      docs = 500.times.map do |i|
        subject.new(name: "User #{i}", birthdate: "#{rand(20)+1980}-#{rand(11)+1}-#{rand(28)+1}").tap(&:update)
      end

      subject.remap!

      docs.sample(50).each(&:update)
      docs.sample(50).each(&:delete)

      # sleep 0.1 while subject.remapping?

      subject.flush_index
      results = subject.search(sort: :name, size: docs.length)
      expect(results.total).to eq(docs.length - 50)
    end
  end
end