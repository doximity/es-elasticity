module Elasticity
  class Document
    include ::ActiveModel::Model

    class NotConfigured < StandardError; end

    Config = Struct.new(:index_base_name, :document_type, :mapping, :strategy)

    # Configure the given klass, changing default parameters and resetting
    # some of the internal state.
    def self.configure
      @config = Config.new
      @config.strategy = Strategies::SingleIndex
      yield(@config)
    end

    # Returns the stategy class being used.
    # Check Elasticity::Strategies for more information.
    def self.strategy
      if @config.nil? || @config.strategy.nil?
        raise NotConfigured, "#{self} has not been configured, make sure you call the configure method"
      end

      return @strategy if defined?(@strategy)

      if namespace = Elasticity.config.namespace
        index_base_name = "#{namespace}_#{@config.index_base_name}"
      end

      @strategy = @config.strategy.new(Elasticity.config.client, index_base_name, document_type)
    end

    # Document type
    def self.document_type
      if @config.nil? || @config.document_type.blank?
        raise NotConfigured, "#{self} has not been configured, make sure you call the configure method"
      end

      @config.document_type
    end

    # Document type
    def self.mapping
      if @config.nil? || @config.mapping.blank?
        raise NotConfigured, "#{self} has not been configured, make sure you call the configure method"
      end

      @config.mapping
    end

    # Creates the index for this document
    def self.create_index
      self.strategy.create_if_undefined(settings: Elasticity.config.settings, mappings: { document_type => mapping })
    end

    # Re-creates the index for this document
    def self.recreate_index
      self.strategy.recreate(settings: Elasticity.config.settings, mappings: { document_type => mapping })
    end

    # Deletes the index
    def self.delete_index
      self.strategy.delete
    end

    # Does the index exist?
    def self.index_exists?
      !self.strategy.missing?
    end

    # Gets the index name to be used when you need to reference the index somewhere.
    # This depends on the strategy being used, but it always refers to the search index.
    def self.ref_index_name
      self.strategy.ref_index_name
    end

    # Remap
    def self.remap!
      self.strategy.remap(settings: Elasticity.config.settings, mappings: { document_type => mapping })
    end

    # Flushes the index, forcing any writes
    def self.flush_index
      self.strategy.flush
    end

    # Creates a instance of a document from a ElasticSearch hit data.
    def self.from_hit(hit_data)
      attrs = { _id: hit_data["_id"] }
      attrs.merge!(hit_data["_source"]) if hit_data["_source"]

      if hit_data["highlight"]
        highlighted_attrs = attrs.dup
        attrs_set = Set.new

        hit_data["highlight"].each do |name, v|
          name = name.gsub(/\..*\z/, '')
          next if attrs_set.include?(name)
          highlighted_attrs[name] = v
          attrs_set << name
        end

        highlighted = new(highlighted_attrs)
      end

      new(attrs.merge(highlighted: highlighted))
    end

    # Searches the index using the parameters provided in the body hash, following the same
    # structure Elasticsearch expects.
    # Returns a DocumentSearch object.
    def self.search(body)
      search = self.strategy.search(self.document_type, body)
      Search::DocumentProxy.new(search, self)
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

    # Bulk delete documents matching provided ids
    def self.bulk_delete(ids)
      self.strategy.bulk do |b|
        ids.each do |id|
          b.delete(self.document_type, id)
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
      self._id, @created = self.class.strategy.index_document(self.class.document_type, _id, to_document)
    end

    def delete
      self.class.delete(self._id)
    end

    def created?
      @created || false
    end
  end
end
