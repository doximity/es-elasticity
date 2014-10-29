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
end