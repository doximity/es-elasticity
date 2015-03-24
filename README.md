# Elasticity

[![Build Status](https://travis-ci.org/doximity/es-elasticity.svg)](https://travis-ci.org/doximity/es-elasticity) [![Test Coverage](https://codeclimate.com/github/doximity/es-elasticity/badges/coverage.svg)](https://codeclimate.com/github/doximity/es-elasticity) [![Code Climate](https://codeclimate.com/github/doximity/es-elasticity/badges/gpa.svg)](https://codeclimate.com/github/doximity/es-elasticity) [![Dependency Status](https://gemnasium.com/doximity/es-elasticity.svg)](https://gemnasium.com/doximity/es-elasticity)

Elasticity is a model oriented approach to Elasticsearch. In simple words, a Document is represented by it's own class, similar to what ActiveRecord does for database rows.

In Elasticsearch terminology, a document is an entity stored in Elasticsearch and associated to an index. Whenever a search is performed, a collection of documents is returned.

Elasticity maps those documents into objects, providing a rich object representation of a document.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'es-elasticity', require "elasticity"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install es-elasticity

## Usage

### Document model definition

The first thing to do, is setup a model representing your documents. The class level represents the index, while the instance level represents each Document stored in the index. This is similar to how ActiveRecord maps tables vs rows.

```ruby
class Search::User < Elasticity::Document
  configure do |c|
    # Defines how the index will be named, the final name
    # will depend on the stragy being used.
    c.index_base_name = "users"

    # Defines the document type that this class represents.
    c.document_type = "user"

    # Select which strategy should be used. AliasIndex uses two aliases
    # in order to support hot remapping of indexes. This is the recommended
    # strategy.
    c.strategy = Elasticity::Strategies::AliasIndex

    # Defines the mapping for this index/document_type.
    c.mapping  = {
      properties: {
        name: { type: "string" },
        birthdate: { type: "date" },
      }
    }
  end

  # Defines a search method.
  def self.adults
    date = Date.today - 21.years

    # This is the query that will be submited to ES, same format ES would 
    # expect, translated to a Ruby hash.
    body = {
      filter: {
        { range: { birthdate: { gte: date.iso8601 }}},
      },
    }

    # Creates a search object from the body and return it. The returned object # is a lazy evaluated search that behaves like a collection, being 
    # automatically triggered when data is iterated over.
    self.search(body)
  end

  # All models automatically have the id attribute but you need to define the 
  # other accessors so that they can be set and get properly.
  attr_accessor :name, :birthdate

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

### Indexing

An instance of the model is an in-memory representation of a Document. The document can be stored on the index by calling the `update` method.

```ruby
# Creates a new document on the index
u = Search::User.new(id: 1, name: "John", birthdate: Date.civil(1985, 10, 31))
u.update

# Updates the same document on the index
u.name = "Jonh Jon"
u.update
```

If you need to index a collection of documents, you can use `bulk_index`:

```ruby
users = [
  Search::User.new(id: 1, name: "John", birthdate: Date.civil(1985, 10, 31)),
  Search::User.new(id: 2, name: "Mary", birthdate: Date.civil(1986, 9, 24)),
]

Search::User.bulk_index(users)
```


### Searching

Class methods have access to the `search` method, which returns a lazy evaluated search. That means that the search will only be performed when the data is necessary, not when the `search` method is called.

The search object implements `Enumerable`, so it can be treated as a collection:

```ruby
# Get the search object, which is an instance of `Elasticity::DocumentSearchProxy`.
# Search is not performed until data is accessed.
adults = User.adults

# Iterating over the results will trigger the query
adults.each do |user|
  # do something with user
end
```

It also has some pretty interesting methods that affects the way the query is performed. Here is a list of available search types:

```ruby
# Returns an array of document instances, this is the default and what the 
# enumerable methods will delegate to.
adults.documents

# Returns an array of hashes representing the documents.
adults.document_hashes

# Performs the search using scan&scroll. It returns a cursor that will lazily
# fetch all the pages of the search. It can be iterated by batch/page or by 
# document.
cursor = adults.scan_documents
cursor.each_batch { |batch| ... }
cursor.each { |doc| ... }

# Lastly, a search that maps back to an ActiveRecord::Relation.
adults = adults.active_record(User)
```

For more information about the `active_record` method, read [ActiveRecord integration](#activerecord-integration).

### Strategies and HotRemapping

Strategies define how index creation and index operation happens on the lower level. Basically it define the structure that backs the document model. Currently, there are two strategies available: single-index and alias-index.

The single-index strategy is the most straightforward one. It causes one index to be created and any operation will be performed directly on that index. It's very simple but it has the downside of being a lot harder to update existing mapping since you'll have to drop the index and recreate from scratch.

The alias-index strategy is a bit more complex but it allows for seameless hot remapping. It works by creating an index and two aliases pointing to that index. Any operation is performed on the aliases rather than the index, which allows hot swapping due atomic aliases updates.

Here is what it looks like:

```
|¯¯¯¯¯¯¯¯¯¯¯¯¯|
|  MainAlias  |---------|
|_____________|         |------------> |¯¯¯¯¯¯¯¯¯¯¯¯¯|
                                       |    Index    |
|¯¯¯¯¯¯¯¯¯¯¯¯¯|         |------------> |_____________|
| UpdateAlias |---------|
|_____________| 
```

Everytime a search operation is performed, it is performed against the main alias; when an update operation is performed, it is performed against the update alias; and, when a delete operation is performed, it is performed against the indexes pointed by both aliases.

When the mapping needs to change, a hot remapping can be performed by doing the following:

1. Create a new index with the new mapping;
2. change the update alias to point to the new index, and change main alias to point to both indexes; at this point it will look something like this:

  ```
  |¯¯¯¯¯¯¯¯¯¯¯¯¯|----------------------> |¯¯¯¯¯¯¯¯¯¯¯¯¯|
  |  MainAlias  |                        |  Old Index  |
  |_____________|----------|             |_____________|
                           |                           
  |¯¯¯¯¯¯¯¯¯¯¯¯¯|          |-----------> |¯¯¯¯¯¯¯¯¯¯¯¯¯|
  | UpdateAlias |----------------------> |  New Index  |
  |_____________|                        |_____________|
  ```

3. iterate over all documents on the old index, copying them to the new index;
4. change aliases to point only to the new index;
5. delete the old index.

This is a simplified version, there are other things that happen to ensure consistency and avoid race conditions. For full understanding see `Elasticity::Strategies::AliasIndex#remap`.

### ActiveRecord integration

ActiveRecord integration is mainly a set of conventions rather than implementation, with the exception of one method that allows mapping documents back to a relation. Here is the list of conventions:

* have a class method on the document called `from_active_record` that creates a document object from the active record object;
* have a class method on the Document for rebuilding the index from the records;
* have an `after_save` and an `after_destroy` callbacks on the ActiveRecord model;

For example:

  ```ruby
  class User < ActiveRecord::Base
    after_save    :update_index_document
    after_destroy :delete_index_document

    def update_index_document
      Search::User.from_active_record(self).update
    end

    def remove_index_document
      Search::User.delete(self.id)
    end
  end

  class Search::User < Elasticity::Document
    # ... configuration

    def self.from_active_record(ar)
      new(name: ar.name, birthdate: ar.birthdate)
    end

    def self.rebuild_index
      self.recreate_index

      User.find_in_batches do |batch|
        documents = batch.map { |record| from_active_record(record) }
        self.bulk_index(documents)
      end
    end
  end
  ```

This makes the code very clear in intent, easier to see when and how things happen and under the developer control, keeping both parts very decoupled.

The only ActiveRecord specific utility this library have is a way to lazily map a Elasticsearch search to an ActiveRecord relation.

To extend on the previous example, imagine the `Search::User` class also have the following simple search method.

```ruby
def self.adults
  date = Date.today - 21.years
  
  body = {
    filter: {
      { range: { birthdate: { gte: date.iso8601 }}},
    },
  }

  self.search(body)
end
```

Because the return of that method is a lazy-evaluated search, it allows specific search strategies to be used, one of them being ActiveRecord specific:

```ruby
adults = Search::User.adults.active_record(User)
adults.class # => ActiveRecord::Relation
adults.all   # => [#<User: id: 1, name: "John", birthdate: 1985-10-31>, ...]
```

Note that the method takes a relation and not a class, so the following is also possible:

```ruby
Search::User.adults.active_record(User.where(active: true))
```

## Roadmap

- [ ] Make Elasticity::Strategies::AliasIndex the default
- [ ] Use mapping instead of mappings, we wanna be consistent to ES not to elasticsearch-ruby
- [ ] Define from_active_record interface
- [ ] Write more detailed documentation section for:
  - [ ] Model definition
  - [ ] Indexing, Bulk Indexing and Delete By Query
  - [ ] Search and Multi Search
  - [ ] ActiveRecord integration
- [ ] Better automatic index name and document type
- [ ] Support for multiple document types
- [ ] Get rid of to_document, generate automatically based on attributes
- [ ] Add some delegations on Document to Index

## Contributing

1. Fork it ( https://github.com/[my-github-username]/elasticity/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
