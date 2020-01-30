# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.13.3.pre1] - 2020-01-30
### Changed
- Release on RubyGems using gem-publisher CircleCI Orb

## [0.13.2] - 2020-01-29
### Changed
- Release on Nexus using gem-publisher CircleCI Orb
- Packing gems
- bump the version for testing the Nexus repo

## [0.13.1]
### Changed
- remove superfluous 'to_ary' delegation that was causing issues downstream

## [0.13.0]
### Changed
- changes needed for use with Elasticsearch v7
- handle the v7 "total" as an object rather than a scalar
- use timestamp with no colons
- update elasticsearch gem version for consistency with target ES version
- expose refresh_index to force write (because in v7, flush no longer forces writes)
- allow for optional 'include_type_name_on_create' arg so that the :include_type_name can be passed

## [0.12.1]
### Changed
- use Arel.sql to avoid unsafe sql and eliminate deprecation warnings when used in Rails projects

## [0.12.0]
### Changed
- warn when configuring a index with subclasses if using ES version that does support them
- raise exception when creating or adding document to an index configured with subclasses if using an ES version that does not support them

## [0.11.5]
### Changed
- Give the option of retrying the deletion for certain exceptions during remap

## [0.11.4]
### Changed
- Fully clean up if error occurs during remap (assign all aliases back to original index)

## [0.11.3]
### Added
- Adds support for preserving the order or normalized names of `highlight` through `highlighted_attrs`

## [0.11.2]
### Added
- Adds support for passing arguments to Search definition through `search(query, search_args)` in index searching and msearch
- adds `_explanation` to hold value of returned explanations in the base document

## [0.11.1]
### Changed
- support `action.destructive_requires_name` setting by being explict about which indices to delete

## [0.11.0]
### Changed
- compatibilty with ES v6
- change mappings for 'index' to boolean. "string" type was replaced with "text"
- use "successful" from API response ('created' was removed)
- stringify keys for :mappings so clients can use symbol keys

## [0.10.0]
### Changed
- update remap to removing fields from the mapping that are not explicitly defined.

## [0.9.1]
### Changed
- fix search enumerator, missing first result set

## [0.8.3]
### Changed
- fix remap method to use the scan api properly.

## [0.8.2]
### Changed
- fix scan api to work with more recent versions of elasticsearch ruby.

## [0.8.1]
### Changed
- loosen support for elasticsearch-ruby versions to support more versions of elasticsearch

## [0.8.0]
### Changed
- Make Elasticity::Strategies::AliasIndex the default
- Use mapping instead of mappings, we wanna be consistent to ES not to elasticsearch-ruby
- Better automatic index name and document type

## [v0.7.1]
### Added
- add more response info to raised exceptions from reindexing

## [v0.6.5]
### Changed
- update search and multi search interfaces to allow passing of general search definition arguments found in https://github.com/elastic/elasticsearch-ruby/blob/bdf5e145e5acc21726dddcd34492debbbddde568/elasticsearch-api/lib/elasticsearch/api/actions/search.rb#L125-L162

## [v0.6.4]
### Changed
- update suggestions to pull from the proper key

## [v0.6.3]
### Added
- add next_page and previous_page to be compatible with will_paginate interface

## [0.6.2]
### Changed
- update multi search `[]` method to raise an exception with key name to make it easier to debug failed queries within a multi search hash.

## [0.6.0]
### Changed
- Change documents to be able to define indexes with multiple doc types.  A Document class can define subclasses which are of different doc_types and all live in the same index's mappings.
- updated search queries to pass either a list of document types or a single document type.
- Update documents to generate a default document_type from the class name so that Documents always have a document type. You'll still usually want to manually define the document type, but it's no longer necessary.

## [0.5.2]
### Added
- Add aggregations to multi_search

## [0.5.1]
### Added
- Add ability to reindex individual attributes of a document using the bulk_update API.

## [v0.5.0]
### Changed
- Refactor of multisearch and search facade
- Searches no longer return a simple array, they now return the Search::Results object which proxies array and is enumerable.

### Added
- add Search::Results proxy object so pagination and meta data methods can be standardize across all responses

## [v0.4.5]
### Changed
- Fix issue with hash strings and pagination

## [v0.4.4]
### Added
- Added support for surfacing document `_score` on query results.
