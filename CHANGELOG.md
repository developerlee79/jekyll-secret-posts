# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1]

Security release. Secret URLs are unchanged: the token derivation is untouched
and is now pinned by tests, so links already shared keep working.

### Fixed

- Files in the secret directory without YAML front matter were published
  unhashed. Jekyll reads them as static files, which never reach the tokenizer
  or the meta injection, so they were served verbatim at the collection default
  `/<collection_name>/<path>` — no token, no `noindex`. This affected
  attachments placed next to a secret post, and posts whose front matter block
  was missing. Such files are now dropped from the build and named in a warning.
- `source_dir` un-excluded a directory Jekyll serves as ordinary content. The
  key never moved anything, but it was what got stripped from `exclude`, so a
  value without a leading underscore re-published a directory the site had
  excluded on purpose. The source directory is now derived from
  `collection_name`, and only that underscored path is ever un-excluded.
- The `noindex` meta was injected by matching a literal `<head>`, so a theme
  opening the head with attributes fell through to prepending ahead of the
  doctype — quirks mode, and a robots meta outside `<head>` that crawlers
  ignore.
- The redirect page at `url_prefix` carried no `noindex` and stayed indexable.
- `redirect_url` and `baseurl` reached the redirect page unvalidated. Only
  `http(s)://` URLs and root-relative paths are accepted now; anything else
  warns and falls back to `/`.
- `list_urls` treated any non-blank value as true, so a quoted `"false"`
  switched secret URL logging on. It now requires a YAML boolean.

### Added

- `<meta name="referrer" content="no-referrer">` on every secret page, so the
  secret URL is not handed to third parties in the `Referer` header of outbound
  links, images, and scripts.
- A build warning when `JEKYLL_SECRET_SALT` is unset or shorter than 16
  characters. Without a salt the hashed input is only the collection name and
  the file path, both usually public in the site repository.
- A build warning when a configured `source_dir` disagrees with the directory
  Jekyll reads, and when the plugin takes over a collection the site already
  declared.
- Documentation of what the plugin does and does not protect, including that
  templates iterating `site.documents` will publish every secret URL into a
  search index.
- Continuous integration running the test suite across supported Ruby versions,
  the linter, and a gem build.

### Changed

- `source_dir` is derived from `collection_name` rather than read from the
  configuration. Setting it to a directory that does not match is ignored with
  a warning.

## [0.1.0]

Initial release.
