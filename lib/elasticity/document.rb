module Elasticity
  class Document
    include ::ActiveModel::Model

    # Returns the instance of Elasticity::Index associated with this document.
    def self.index
      return @index if @index.present?
      @index = Index.new(Elasticity.config.client, self.namespaced_index_name)
    end

    # Creates the index for this document
    def self.create_index
      self.index.create_if_undefined(settings: Elasticity.config.settings, mappings: { document_type => @mappings })
    end

    # Re-creates the index for this document
    def self.recreate_index
      self.index.recreate(settings: Elasticity.config.settings, mappings: { document_type => @mappings })
    end

    # Deletes the index
    def self.delete_index
      self.index.delete
    end

    # The index name to be used for indexing and storing data for this document model.
    # By default, it's the class name converted to underscore and plural.
    def self.index_name
      return @index_name if defined?(@index_name)
      @index_name = self.name.underscore.pluralize
    end

    # Sets the index name to something else than the default
    def self.index_name=(name)
      @index_name = name
      @index = nil
    end

    # Namespaced index name
    def self.namespaced_index_name
      name = self.index_name

      if namespace = Elasticity.config.namespace
        name = "#{namespace}_#{name}"
      end

      name
    end

    # The document type to be used, it's inferred by the class name.
    def self.document_type
      return @document_type if defined?(@document_type)
      @document_type = self.name.demodulize.underscore
    end

    # Sets the document type to something different than the default
    def self.document_type=(document_type)
      @document_type = document_type
    end

    # Sets the mapping for this model, which will be used to create the associated index and
    # generate accessor methods.
    def self.mappings=(mappings)
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
        new(doc["_source"].merge(_id: doc['_id']))
      end
    end

    # Removes one specific document from the index.
    def self.delete(id)
      index.delete_document(document_type, id)
    end

    # Removes entries based on a search
    def self.delete_by_search(search)
      index.delete_by_query(document_type, search.body)
    end

    # Bulk index the provided documents
    def self.bulk_index(documents)
      index.bulk do |b|
        documents.each do |doc|
          b.index(self.document_type, doc._id, doc.to_document)
        end
      end
    end

    # Define common attributes for all documents
    attr_accessor :_id

    # Creates a new Document instance with the provided attributes.
    def initialize(attributes = {})
      super(attributes)
    end

    def attributes=(attributes)
      attributes.each do |attr, value|
        self.public_send("#{attr}=", value)
      end
    end

    # Defines equality by comparing the ID and values of each instance variable.
    def ==(other)
      return false if _id != other._id

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

    # Update this object on the index, creating or updating the document.
    def update
      self.class.index.index_document(self.class.document_type, _id, to_document)
    end
  end
end
