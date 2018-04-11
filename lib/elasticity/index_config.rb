module Elasticity
  class IndexConfig
    class SubclassError < StandardError; end

    SUBCLASSES_NOT_AVAILABLE = "subclasses are not available in this version of Elasticsearch".freeze
    VERSION_WITHOUT_SUBCLASSES = "6.0.0".freeze
    ATTRS = [
      :index_base_name, :document_type, :mapping, :strategy, :subclasses,
      :settings
    ].freeze
    VALIDATABLE_ATTRS = [:index_base_name, :document_type, :strategy].freeze

    attr_accessor(*ATTRS)

    def initialize(elasticity_config, defaults = {})
      defaults.each do |k,v|
        instance_variable_set("@#{k}",v)
      end
      @elasticity_config = elasticity_config
      yield(self)
      subclasses_warning
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
      @definition = {
        settings: merge_settings, mappings: { @document_type => @mapping&.deep_stringify_keys || {} }
      }
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
      @strategy ||= Strategies::AliasIndex
    end

    def check_subclass_exception
      raise SubclassError.new(SUBCLASSES_NOT_AVAILABLE) if should_not_use_subclasses?
    end

    private

    def validate!
      VALIDATABLE_ATTRS.each do |attr|
        raise "#{attr} is not set" if public_send(attr).nil?
      end
    end

    def merge_settings
      @elasticity_config.settings.merge(settings || {})
    end

    def should_not_use_subclasses?
      subclasses&.any? && version_does_not_support_subclasses?
    end

    def subclasses_warning
      if should_not_use_subclasses?
        Warning.warn SUBCLASSES_NOT_AVAILABLE
      end
    end

    def version_does_not_support_subclasses?
      client.versions.any?{ |v| v >= VERSION_WITHOUT_SUBCLASSES }
    end
  end
end
