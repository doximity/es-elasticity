RSpec.describe "Segmented indexes", elasticsearch: true do
  subject do
    Class.new(Elasticity::SegmentedDocument) do
      def self.name
        "SomeClass"
      end

      configure do |c|
        c.index_base_name = "people"
        c.document_type = "person"
        c.mapping = {
          properties: {
            name: { type: "text" },
          },
        }
      end

      attr_accessor :name

      def self.by_name(name)
        search(query: { match: { name: name } })
      end

      def to_document
        { name: name }
      end
    end
  end

  def ensure_index(*segments)
    @indexed ||= []
    segments.each(&:recreate_index)
    @indexed += segments
  end

  after do
    Array(@indexed).each { |i| i.delete_index }
  end

  it "allows all operations on a segment" do
    seg = subject.segment("A")
    ensure_index(seg)

    rodrigo = seg.new(name: "rodrigo")

    id, success = rodrigo.update
    expect(id).to be_kind_of(String)
    expect(success).to be true

    seg.refresh_index
    results = seg.by_name("rodrigo").to_a.first
    expect(results.class).to eq rodrigo.class
    expect(results.name).to eq rodrigo.name

    rodrigo.delete
    seg.refresh_index

    results = seg.by_name("rodrigo").to_a
    expect(results).to be_empty
  end

  it "isolates segments from one another" do
    seg_a = subject.segment("A")
    seg_b = subject.segment("B")
    ensure_index(seg_a, seg_b)

    doc_a = seg_a.new(name: "doc a")
    _, success = doc_a.update
    expect(success).to be true

    doc_b = seg_b.new(name: "doc b")
    _, success = doc_b.update
    expect(success).to be true

    seg_a.refresh_index
    seg_b.refresh_index

    res_a = seg_a.by_name("doc").to_a.first
    expect(res_a.class).to eq doc_a.class
    expect(res_a.name).to eq doc_a.name

    res_b = seg_b.by_name("doc").to_a.first
    expect(res_b.class).to eq doc_b.class
    expect(res_b.name).to eq doc_b.name
  end
end
