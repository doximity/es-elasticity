module Elasticity
  class Document < BaseDocument
    IndexMapper.set_delegates(singleton_class, :@mapper)

    # Configure the given klass, changing default parameters and resetting
    # some of the internal state.
    def self.configure(&block)
      config  = IndexConfig.new(Elasticity.config, &block)
      @mapper = IndexMapper.new(self, config)
    end
  end
end
