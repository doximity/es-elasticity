Changelog
=========
## 0.13.2
  * Release on Nexus using gem-publisher CircleCI Orb
  * Packing gems
  * bump the version for testing the Nexus repo
v0.13.1
  - remove superfluous 'to_ary' delegation that was causing issues downstream
v0.13.0
  - changes needed for use with Elasticsearch v7
  - handle the v7 "total" as an object rather than a scalar
  - use timestamp with no colons
  - update elasticsearch gem version for consistency with target ES version
  - expose refresh_index to force write (because in v7, flush no longer forces writes)
  - allow for optional 'include_type_name_on_create' arg so that the :include_type_name can be passed
v0.12.1
  - use Arel.sql to avoid unsafe sql and eliminate deprecation warnings when used in Rails projects
v0.12.0
  - warn when configuring a index with subclasses if using ES version that does support them
  - raise exception when creating or adding document to an index configured with subclasses if using
     an ES version that does not support them
v0.11.5
 - Give the option of retrying the deletion for certain exceptions during remap
v0.11.4
 - Fully clean up if error occurs during remap (assign all aliases back to original index)
v0.11.3
 - Adds support for preserving the order or normalized names of `highlight` through `highlighted_attrs`

v0.11.2
 - Adds support for passing arguments to Search definition through `search(query, search_args)` in index searching and msearch
 - adds _explanation to hold value of returned explanations in the base document

v0.11.1
  - support `action.destructive_requires_name` setting by being explict about which indices to delete

v0.11.0
  - compatibilty with ES v6
    - change mappings for 'index' to boolean. "string" type was replaced with "text"
    - use "successful" from API response ('created' was removed)
  - stringify keys for :mappings so clients can use symbol keys
v0.10.0
	- update remap to removing fields from the mapping that are not explicitly
	defined.
v0.9.1
	- fix search enumerator, missing first result set
v0.8.3
	- fix remap method to use the scan api properly.
v0.8.2
	- fix scan api to work with more recent versions of elasticsearch ruby.
v0.8.1
	- loosen support for elasticsearch-ruby versions to support more versions of
	elasticsearch
v0.8.0
 - Make Elasticity::Strategies::AliasIndex the default
 - Use mapping instead of mappings, we wanna be consistent to ES not to elasticsearch-ruby
 - Better automatic index name and document type
v0.7.1
	- add more response info to raised exceptions from reindexing
v0.6.5
	- update search and multi search interfaces to allow passing of general
	search definition arguments found in https://github.com/elastic/elasticsearch-ruby/blob/bdf5e145e5acc21726dddcd34492debbbddde568/elasticsearch-api/lib/elasticsearch/api/actions/search.rb#L125-L162
v0.6.4
	- update suggestions to pull from the proper key
v0.6.3
	- add next_page and previous_page to be compatible with will_paginate
	interface
v0.6.2
	- update multi search `[]` method to raise an exception with key name to
	make it easier to debug failed queries within a multi search hash.
v0.6.0
	- Change documents to be able to define indexes with multiple doc types.  A
	Document class can define subclasses which are of different doc_types and
	all live in the same index's mappings.
	- updated search queries to pass either a list of document types or a single
	document type.
	- Update documents to generate a default document_type from the class name
	so that Documents always have a document type. You'll still usually want to
	manually define the document type, but it's no longer necessary.
v0.5.2
  - Add aggregations to multi_search
v0.5.1
  - Add ability to reindex individual attributes of a document using the
  bulk_update API.
v0.5.0
	- Refactor of multisearch and search facade
	- add Search::Results proxy object so pagination and meta data methods can
	be standardize across all responses
  - Searches no longer return a simple array, they now return the
  Search::Results object which proxies array and is enumerable.
v0.4.5
  - Fix issue with hash strings and pagination
v0.4.4
  - Added support for surfacing document _score on query results.
