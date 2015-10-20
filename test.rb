class Person < Elasticity::SegmentedDocument
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

seg = Person.segment("doximity")
p seg # => Person(doximity)
p seg.recreate_index # => {"acknowledged"=>true}

a = seg.new(name: "rodrigo")
a.update

seg.flush_index
p seg.by_name("rodrigo").to_a # => [#<Person(doximity):0x81872bcec1d5 @name="rodrigo" @_id="AVCCkxi2yttLSz7M-rx1" @highlighted=nil>]
