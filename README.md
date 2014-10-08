# Elasticity

Elasticity provides a higher level abstraction on top of [elasticsearch-ruby](https://github.com/elasticsearch/elasticsearch-ruby) gem.

Mainly, it provides a model-oriented approach to ElasticSearch, similar to what [ActiveRecord](https://github.com/rails/rails/tree/master/activerecord) provides to relational databases. It leverages [ActiveModel](https://github.com/rails/rails/tree/master/activemodel) to provide a familiar format for Rails developers.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'elasticity'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install elasticity

## Usage overview

The first thing to do, is setup a model class for a index and document type that inherits from `Elasticity::Document`.

```ruby
class Search::User < Elasticity::Document
  # All models automatically have the id attribute but you need to define the others.
  attr_accessor :name, :birthdate

  # Define the index mapping for the index and document type this model represents.
  self.mappings = {
    properties: {
      name: { type: "string" },
      birthdate: { type: "date" },
    }
  }

  # Defines a search method.
  def self.adults
    date = Date.today - 21.years

    # This is the query that will be submited to ES, same format ES would expect,
    # translated to a Ruby hash.
    body = {
      filter: {
        { range: { birthdate: { gte: date.iso8601 }}},
      },
    }

    # Creates a search object from the body and return it. The returned object is a
    # lazy evaluated search that behaves like a collection, being automatically
    # triggered when data is iterated over.
    self.search(body)
  end

  # to_document is the only required method that needs to be implemented so an
  # instance of this model can be indexed.
  def to_document
    {
      name: self.name,
      birthdate: self.birthdate.iso8601,
    }
  end
end
```

Then instances of that model can be indexed pretty easily by just calling the `update` method.

```ruby
# Creates a new document on the index
u = Search::User.new(id: 1, name: "John", birthdate: Date.civil(1985, 10, 31))
u.update

# Updates the same document on the index
u.name = "Jonh Jon"
u.update
```

Getting the results of a search is also pretty straightforward:

```ruby
# Get the search object, which is an instance of `Elasticity::DocumentSearchProxy`.
# Search is not performed until data is accessed.
adults = User.adults

# Iterating over the results will trigger the query
adults.each do |user|
  # do something with user
end

# Or you can also, map the results back to an ActiveRecord relation.
# In this case, only the ids will be fetched.
adults.active_recors(Database::User) # => Array of Database::User instances
```

## Design Goals

- Provide model specific for ElasticSearch documents instead of an ActiveRecord mixin;
- proper separation of concerns and de-coupling;
- lazy search evaluation and easy composition of multi-searches;
- easy of debug;
- higher level API that resembles ElasticSearch API;

## Roadmap

- [ ] Write more detailed documentation section for:
  - [ ] Model definition
  - [ ] Indexing, Bulk Indexing and Delete By Query
  - [ ] Search and Multi Search
  - [ ] ActiveRecord integration
- [ ] Get rid of to_document, generate automatically based on attributes
- [ ] Add some delegations on Document to Index
- [ ] Define from_active_record interface

## Contributing

1. Fork it ( https://github.com/[my-github-username]/elasticity/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
