module Elasticity
  class Document < BaseDocument
    IndexMapper.set_delegates(singleton_class, :mapper)

    private

    def self.mapper
      raise "document class not configured" unless config.present?
      @mapper ||= IndexMapper.new(self, config)
    end
  end
end
