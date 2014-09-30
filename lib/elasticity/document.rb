module Elasticity
  class Document
    include ::ActiveModel::Model

    # Sets the elasticsearch index name for this model
    class_attribute :index_name

    # Sets the default document type for the model
    class_attribute :default_document_type

    # Defines the index settings and mappings
    class_attribute :index_mapping

    # Score is a common attribute for all results
    attr_accessor :score

    def self.to_document(object)
      raise NoMethodError, "self.to_document needs to be defined on #{self}"
    end

    def self.index(object)
      if doc = self.to_document(object)
        _index_instance.add_document(default_document_type, object.id, doc)
      end
    end

    def self.remove(id)
      _index_instance.del_document(default_document_type, id)
    end

    def self.get(id)
      from_document(_index_instance.get_document(default_document_type, id))
    end

    def self.search(body)
      Search.new(_index_instance, default_document_type, self, body)
    end

    def self.from_document(doc)
      attrs = doc["_source"].merge(score: doc["_score"])
      self.new(attrs)
    end

    private

    def self.scoped_index_name
      Elasticity.config.namespace
      "#{Elasticity.config.namespace}_#{index_name}"
    end

    def self._index_instance
      return @_index_instance if defined?(@_index_instance)

      namespaced_index_name = [Elasticity.config.namespace, index_name].compact.join("_")

      @index = Index.new(Elasticity.config.client, namespaced_index_name, settings: Elasticity.config.settings, mappings: self.index_mapping)
      @index.create_if_undefined
      @index
    end
  end
end
