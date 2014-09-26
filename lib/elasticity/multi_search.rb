module Elasticity
  class MultiSearch
    def initialize
      @searches = []
      yield self if block_given?
    end

    def add(name, search:, database: nil)
      @searches << { name: name, search: search, database: database }
    end

    def [](search_name)
      results[search_name]
    end

    private

    def results
      return @results if defined?(@results)

      body = @searches.map do |search_def|
        search = search_def[:search]
        { index: search.index_name, type: search.document_type, search: search.body }
      end

      multi_resp = Elasticity.client.msearch(body: body)

      @results = {}

      @searches.each_with_index do |search_def, idx|
        rs = ResultSet.new(search_def[:search].document_klass, multi_resp["responses"][idx])

        if relation = search_def[:database]
          @results[search_def[:name]] = rs.database(relation)
        else
          @results[search_def[:name]] = rs.documents
        end
      end

      @results
    end
  end
end
