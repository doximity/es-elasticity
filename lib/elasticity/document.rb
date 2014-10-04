module Elasticity
  class Document
    include ::ActiveModel::Model

    # Returns the instance of Elasticity::Index associated with this document.
    def self.index
      return @index if defined?(@index)

      index_name = self.name.underscore.pluralize

      if namespace = Elasticity.config.namespace
        index_name = "#{namespace}_#{index_name}"
      end

      @index = Index.new(Elasticity.config.client, index_name)
      @index.create_if_undefined(settings: Elasticity.config.settings, mappings: @mappings)
      @index
    end

    # The index name to be used for indexing and storing data for this document model.
    # By default, it's the class name converted to underscore and plural.
    def self.index_name
      self.index.name
    end

    # The document type to be used, it's inferred by the class name.
    def self.document_type
      self.name.underscore
    end

    # Sets the mapping for this model, which will be used to create the associated index and
    # generate accessor methods.
    def self.define_mappings(mappings)
      raise "Can't re-define mappings in runtime" if defined?(@mappings)
      @mappings = mappings
    end

    # Searches the index using the parameters provided in the body hash, following the same
    # structure ElasticSearch expects.
    # Returns a DocumentSearch object.
    def self.search(body)
      DocumentSearchProxy.new(Search.new(index, document_type, body), self)
    end

    # Fetches one specific document from the index by ID.
    def self.get(id)
      if doc = index.get_document(document_type, id)
        new(doc["_source"])
      end
    end

    # Removes one specific document from the index.
    def self.delete(id)
      index.delete_document(document_type, id)
    end

    # Define common attributes for all documents
    attr_accessor :id

    # Creates a new Document instance with the provided attributes.
    def initialize(attributes = {})
      super(attributes)
    end

    # Defines equality by comparing the ID and values of each instance variable.
    def ==(other)
      return false if id != other.id

      instance_variables.all? do |ivar|
        instance_variable_get(ivar) == other.instance_variable_get(ivar)
      end
    end

    # IMPLEMENT
    # Returns a hash with the attributes as they should be stored in the index.
    # This will be stored as _source attributes on ElasticSearch.
    def to_document
      raise NotImplementedError, "to_document needs to be implemented for #{self.class}"
    end

    # Save this object on the index, creating or updating the document.
    def save
      self.class.index.index_document(self.class.document_type, id, to_document)
    end
  end
end
