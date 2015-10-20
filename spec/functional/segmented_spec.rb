RSpec.describe "Segmented indexes", elasticsearch: true do
  subject do
    Class.new(Elasticity::SegmentedDocument) do
      configure do |c|
        c.index_base_name = "people"
        c.document_type = "person"
        c.mapping = {
          properties: {
            name: { type: "string" },
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

    seg.flush_index
    results = seg.by_name("rodrigo").to_a
    expect(results).to eq [rodrigo]

    rodrigo.delete
    seg.flush_index

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

    seg_a.flush_index
    seg_b.flush_index

    res_a = seg_a.by_name("doc").to_a
    expect(res_a).to eq [doc_a]

    res_b = seg_b.by_name("doc").to_a
    expect(res_b).to eq [doc_b]
  end
end
