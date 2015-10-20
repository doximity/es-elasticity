module Elasticity
  class IndexConfig
    ATTRS = [:index_base_name, :document_type, :mapping, :strategy].freeze
    attr_accessor *ATTRS

    def initialize(elasticity_config)
      @elasticity_config = elasticity_config
      yield(self)
      validate!
    end

    def segment(name)
      new_config = self.dup
      new_config.index_base_name = "#{index_base_name}_#{name}"
      new_config
    end

    def client
      @elasticity_config.client
    end

    def definition
      { settings: @elasticity_config.settings, mappings: { @document_type => @mapping } }
    end

    def fq_index_base_name
      return @fq_index_base_name if defined?(@fq_index_base_name)

      if namespace = @elasticity_config.namespace
        @fq_index_base_name = "#{namespace}_#{@index_base_name}"
      else
        @fq_index_base_name = @index_base_name
      end

      @fq_index_base_name
    end

    def strategy
      @strategy ||= Strategies::SingleIndex
    end

    private

    def validate!
      ATTRS.each do |attr|
        raise "#{attr} is not set" if public_send(attr).nil?
      end
    end
  end
end
