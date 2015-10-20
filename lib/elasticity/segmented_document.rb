module Elasticity
  class SegmentedDocument < BaseDocument
    def self.segment(segment_name)
      qn = segment_name.camelize

      klass = Class.new(self) do
        class << self; attr_writer :segment_name, :mapper; end

        def self.inspect
          "#{superclass.name}(#{@segment_name})"
        end

        def inspect
          ivars = instance_variables.map do |name|
            "#{name}=#{instance_variable_get(name).inspect}"
          end

          "#<#{self.class.inspect}:0x#{object_id.to_s(15)} #{ivars.join(" ")}>"
        end
      end

      klass.segment_name = segment_name
      klass.mapper = IndexMapper.new(klass, @base_config.segment(segment_name))
      IndexMapper.set_delegates(klass.singleton_class, :@mapper)

      klass
    end

    # Configure the given klass, changing default parameters and resetting
    # some of the internal state.
    def self.configure(&block)
      @base_config = IndexConfig.new(Elasticity.config, &block)
    end
  end
end
