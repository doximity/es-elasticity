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

    # Score is a common attribute for all results
    attr_accessor :score

    def self.to_document(object)
      raise NoMethodError, "self.to_document needs to be defined on #{self}"
    end

    # def self.index(object)
    #   if doc = self.to_document(object)
    #     _index_instance.add_document(default_document_type, object.id, doc)
    #   end
    # end

    def self.remove(id)
      _index_instance.del_document(default_document_type, id)
    end

    def self.get(id)
      from_document(_index_instance.get_document(default_document_type, id))
    end

    def self.search(body)
      Search.new(_index_instance, default_document_type, self.method(:from_document), body)
    end
  end
end
