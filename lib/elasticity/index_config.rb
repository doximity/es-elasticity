module Elasticity
  class IndexConfig
    ATTRS = [:index_base_name, :document_type, :mapping, :strategy, :subclasses].freeze

    attr_accessor *ATTRS

    def initialize(elasticity_config, default_document_type)
      @document_type = default_document_type
      @elasticity_config = elasticity_config
      yield(self)
      validate!
    end

    def segment(name)
      new_config = self.dup
      new_config.index_base_name = "#{index_base_name}_#{name.underscore}"
      new_config
    end

    def client
      @elasticity_config.client
    end

    def definition
      return @definition if defined?(@definition)
      @definition = { settings: @elasticity_config.settings, mappings: { @document_type => @mapping || {} } }
      subclasses.each do |doc_type, subclass|
        @definition[:mappings][doc_type] = subclass.constantize.mapping
      end if subclasses.present?
      @definition
    end

    def document_types
      @document_types ||= definition[:mappings].collect { |doc_type, mapping| doc_type }
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
      validatable_attributes.each do |attr|
        raise "#{attr} is not set" if public_send(attr).nil?
      end
    end

    def validatable_attributes
      ATTRS - [:mapping, :subclasses]
    end
  end
end
