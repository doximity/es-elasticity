module Elasticity
  class ScrollableSearch
    def self.search_type
      if elasticsearch_gem_version < Gem::Version.create("2.0")
        :scan
      else
        :query_then_fetch
      end
    end

    def self.elasticsearch_gem_version
      Gem.loaded_specs["elasticsearch"].version
    end
  end
end
