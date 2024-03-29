module Elasticity
  class BaseDocument
    include ::ActiveModel::Model

    # Stores configuration for this class and all subclasses.
    class_attribute :config

    # Configure the given klass, changing default parameters and resetting
    # some of the internal state.
    def self.configure(&block)
      self.config = IndexConfig.new(Elasticity.config, self.index_config_defaults, &block)
    end

    # Define common attributes for all documents
    attr_accessor :_id, :highlighted, :_score, :sort, :_explanation, :highlighted_attrs, :matched_queries

    def attributes=(attributes)
      attributes.each do |attr, value|
        self.public_send("#{attr}=", value)
      end
    end

    # Defines equality by comparing the ID and values of each instance variable.
    def ==(other)
      return false if other.nil?
      return false if _id != other._id

      instance_variables.all? do |ivar|
        instance_variable_get(ivar) == other.instance_variable_get(ivar)
      end
    end

    # IMPLEMENT
    # Returns a hash with the attributes as they should be stored in the index.
    # This will be stored as _source attributes on Elasticsearch.
    def to_document
      raise NotImplementedError, "to_document needs to be implemented for #{self.class}"
    end

    # Update this object on the index, creating or updating the document.
    def update
      self._id, @created = self.class.index_document(_id, to_document)
    end

    def delete
      self.class.delete(self._id)
    end

    def created?
      @created || false
    end

    private

    def self.index_config_defaults
      {
        document_type: default_document_type,
        index_base_name: default_index_base_name
      }
    end

    def self.default_document_type
      self.name.gsub("::", "_").underscore
    end

    def self.default_index_base_name
      ActiveSupport::Inflector.pluralize(default_document_type)
    end
  end
end
