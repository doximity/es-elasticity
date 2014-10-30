module Elasticity
  class Document
    include ::ActiveModel::Model

    class NotConfigured < StandardError; end

    # Configure the given klass, changing default parameters and resetting
    # some of the internal state.
    def self.configure(index_base_name:, document_type:, mapping: )
      if namespace = Elasticity.config.namespace
        index_base_name = "#{namespace}_#{index_base_name}"
      end

      @document_type = document_type
      @mapping       = mapping
      @strategy      = Strategies::SingleIndex.new(Elasticity.config.client, index_base_name)
    end

    # Returns the stategy class being used.
    # Check Elasticity::Strategies for more information.
    def self.strategy
      raise NotConfigured, "#{self} has not been configured, make sure you call the configure method" if @strategy.nil?
      @strategy
    end

    # Document type
    def self.document_type
      raise NotConfigured, "#{self} has not been configured, make sure you call the configure method" if @document_type.nil?
      @document_type
    end

    # Document type
    def self.mapping
      raise NotConfigured, "#{self} has not been configured, make sure you call the configure method" if @mapping.nil?
      @mapping
    end

    # Creates the index for this document
    def self.create_index
      self.strategy.create_if_undefined(settings: Elasticity.config.settings, mappings: { document_type => @mapping })
    end

    # Re-creates the index for this document
    def self.recreate_index
      self.strategy.recreate(settings: Elasticity.config.settings, mappings: { document_type => @mapping })
    end

    # Deletes the index
    def self.delete_index
      self.strategy.delete
    end

    # Remap
    def self.remap!
    end

    # Flushes the index, forcing any writes
    def self.flush_index
      self.strategy.flush
    end

    # Searches the index using the parameters provided in the body hash, following the same
    # structure Elasticsearch expects.
    # Returns a DocumentSearch object.
    def self.search(body)
      search = self.strategy.search(self.document_type, body)
      DocumentSearchProxy.new(search, self)
    end

    # Fetches one specific document from the index by ID.
    def self.get(id)
      if doc = self.strategy.get_document(document_type, id)
        new(doc["_source"].merge(_id: doc['_id']))
      end
    end

    # Removes one specific document from the index.
    def self.delete(id)
      self.strategy.delete_document(document_type, id)
    end

    # Removes entries based on a search
    def self.delete_by_search(search)
      self.strategy.delete_by_query(document_type, search.body)
    end

    # Bulk index the provided documents
    def self.bulk_index(documents)
      self.strategy.bulk do |b|
        documents.each do |doc|
          b.index(self.document_type, doc._id, doc.to_document)
        end
      end
    end

    # Define common attributes for all documents
    attr_accessor :_id, :highlighted

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
      res = self.class.strategy.index_document(self.class.document_type, _id, to_document)

      if id = res["_id"]
        self._id = id
        @created = res["created"]
        true
      else
        false
      end
    end

    def delete
      res = self.class.delete(self._id)
      res["found"] || false
    end

    def created?
      @created || false
    end
  end
end
