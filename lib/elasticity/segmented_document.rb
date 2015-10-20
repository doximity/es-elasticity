module Elasticity
  class SegmentedDocument < BaseDocument
    # Creates a new segment which behaves almost the same as a Document class dinamically
    # configured to access a segmented index.
    #
    # It creates a new class in runtime that inherits from your defined class, allowing
    # methods defined in your class to be callable from the dynamic class.
    def self.segment(segment_name)
      qn = segment_name.camelize

      klass = Class.new(self) do
        class_attribute :mapper, :segment_name
        IndexMapper.set_delegates(singleton_class, :mapper)

        def self.inspect
          "#{superclass.name}(#{segment_name})"
        end

        def inspect
          ivars = instance_variables.map do |name|
            "#{name}=#{instance_variable_get(name).inspect}"
          end

          "#<#{self.class.inspect}:0x#{object_id.to_s(15)} #{ivars.join(" ")}>"
        end
      end

      klass.segment_name = segment_name
      klass.mapper = IndexMapper.new(klass, config)
      klass
    end
  end
end
