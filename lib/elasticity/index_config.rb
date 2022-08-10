# frozen_string_literal: true

module Elasticity
  class IndexConfig
    class SubclassError < StandardError; end

    SUBCLASSES_WARNING = "Indices created in Elasticsearch 6.0.0 or later may only contain a single mapping type. "\
      "Therefore, doument-type based inheritance has been disabled by Elasticity"
    SUBCLASSES_ERROR = "Mapping types have been completely removed in Elasticsearch 7.0.0. "\
      "Therefore, doument-type based inheritance has been disabled by Elasticity"
    VERSION_FOR_SUBCLASS_WARNING = "6.0.0"
    VERSION_FOR_SUBCLASS_ERROR = "7.0.0"
    ATTRS = [
      :index_base_name, :document_type, :mapping, :strategy, :subclasses,
      :settings, :use_new_timestamp_format, :include_type_name_on_create
    ].freeze
    VALIDATABLE_ATTRS = [:index_base_name, :document_type, :strategy].freeze
    DEPRECATED_ATTRS = [:use_new_timestamp_format, :include_type_name_on_create].freeze

    attr_accessor(*ATTRS)

    def initialize(elasticity_config, defaults = {})
      defaults.each do |k,v|
        instance_variable_set("@#{k}",v)
      end
      @elasticity_config = elasticity_config
      yield(self)
      subclasses_warning_or_exception
      warn_deprecated_config
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
        settings: merge_settings,
        mappings: @mapping.nil? ? {} : @mapping.deep_stringify_keys
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

    private

    def validate!
      VALIDATABLE_ATTRS.each do |attr|
        raise "#{attr} is not set" if public_send(attr).nil?
      end
    end

    def merge_settings
      @elasticity_config.settings.merge(settings || {})
    end

    def warn_deprecated_config
      DEPRECATED_ATTRS.each do |attr|
        ActiveSupport::Deprecation.warn(
          "#{attr} is deprecated and will be "\
          "removed in the next major release."
        ) if public_send(attr).present?
      end
    end

    def subclasses_warning_or_exception
      return if subclasses.nil? || subclasses.empty?
      raise(SubclassError.new(SUBCLASSES_ERROR)) if es_version_meets_or_exceeds?(VERSION_FOR_SUBCLASS_ERROR)
      warn(SUBCLASSES_WARNING) if es_version_meets_or_exceeds?(VERSION_FOR_SUBCLASS_WARNING)
    end

    def es_version_meets_or_exceeds?(test_version)
      client.versions.any?{ |v| v >= test_version }
    end
  end
end
