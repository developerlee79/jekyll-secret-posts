# Jekyll Secret Posts

[![Gem Version](https://badge.fury.io/rb/jekyll-secret-posts.svg)](https://badge.fury.io/rb/jekyll-secret-posts)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Jekyll Secret Posts** is a lightweight, open-source [Jekyll](https://jekyllrb.com) plugin designed to publish "share-only" posts. It easily integrates with any Jekyll project and is compatible with other Jekyll plugins.

At build time, the plugin hashes the Markdown file path with SHA-256 to generate unique URLs. Since these hashed URLs are excluded from sitemaps and search engine indexing, your posts remain accessible only to those with the direct link.

By enabling link-only access, the plugin allows for exclusive content sharing and gives more privacy to your website.

<br>

* [Installation](#installation)
* [Getting Started](#getting-started)
* [Configuration](#configuration)
* [Compatibility](#compatibility)
* [Contributions](#contributions)

<br>

## Installation

### With Bundler

Add `jekyll-secret-posts` gem to your `Gemfile`:

```ruby
gem "jekyll-secret-posts"
```

or use GitHub repository link:

```ruby
gem "jekyll-secret-posts", git: "https://github.com/developerlee79/jekyll-secret-posts.git"
```

### Manual

Or install the gem manually and specify the plugin in your `_config.yml`:

```shell
gem install jekyll-secret-posts
```

```yaml
plugins:
  - jekyll-secret-posts
```

<br>

## Getting Started

Create a `_secret` directory in your Jekyll project root and add markdown file(same as regular posts).

```text
my-jekyll-site/
├── _config.yml
├── _layouts/
└── _secret/
    └── article.md # Any .md files in this directory or its subfolders are supported
```

Since the URL is hashed, you cannot know it without inspecting the built output. The easiest way to see it is in the build log when you build; this plugin only exposes those URLs in the log via the `list_urls` option. 

However, enabling this in production or CI can expose hashed URLs on external servers or in pipeline logs. For that reason, `list_urls` defaults to `false` so you can turn it on manually only in safe environments. 

For this guide, we enable it so you can verify that secret URLs are generated. Add the `list_urls` option to `_config.yml`:

```yaml
secret_posts:
  list_urls: true
```

URLs are hashed with SHA-256 using the `JEKYLL_SECRET_SALT` environment variable as salt. The plugin still builds without it, but what gets hashed is only the collection name and the file path — both of which are usually public in your repository — so **without a salt the URLs are guessable**. The build warns when the salt is missing or shorter than 16 characters.

Use a long random value and keep it out of the repository:

```bash
openssl rand -hex 32
```

Changing the salt changes every secret URL, so previously shared links stop working. Treat it as a long-lived secret.


Set it before build and build:

```bash
export JEKYLL_SECRET_SALT="my-secret"
bundle exec jekyll build
```

or run build with the environment variable:

```bash
JEKYLL_SECRET_SALT="my-secret" bundle exec jekyll build
```

Then you will be able to find the hashed URL in the build log like this:

```log
Secret post URL: /s/eac1bc3d5e2cb1881215f42c7926d462/
        AutoPages: Disabled/Not configured in site.config.
        Pagination: Complete, processed 1 pagination page(s)
                    done in 1.825 seconds.
```

All done! Share the URL only with people who should see the post.

<br>

## Configuration

You can add custom settings to your `_config.yml` as follows:

```yaml
secret_posts:
  source_dir: "_secret"
  collection_name: "secret"
  url_prefix: "/s/"
  index_layout: "default"
  redirect_url: "/"
  list_urls: false
```

| Key | Default | Description |
|----------------------------|---------|-------------|
| `source_dir` | `"_secret"` | Directory containing target Markdown files. **Derived from `collection_name`, not freely configurable** — see below |
| `collection_name` | `"secret"` | Internal Jekyll collection name, and therefore the source directory (`_<collection_name>`) |
| `url_prefix` | `"/s/"` | URL prefix for hashed URLs |
| `index_layout` | `"default"` | Layout used for the redirect page at the `url_prefix` |
| `redirect_url` | `baseurl` | URL to which the `url_prefix` index page redirects (If unset, the site `baseurl` is used; if that is also unset, `/` is used) |
| `list_urls` | `false` | When `true`, prints hashed URLs in Jekyll build log (Use only in safe environment) |

Jekyll resolves a collection's directory as `_<collection_name>` and ignores any other setting, so the source directory follows `collection_name`. To keep secret posts in `_private/`, set `collection_name: "private"` — setting `source_dir: "_private"` alone does nothing. A `source_dir` that disagrees with the derived directory is ignored with a build warning.

`redirect_url` must be either an `http(s)://` URL or a root-relative path such as `/landing`. Anything else — `javascript:`, `data:`, a protocol-relative `//host`, or a bare hostname — is rejected with a build warning and falls back to `/`.

`list_urls` must be a real YAML boolean. A quoted `"true"` is a string, not `true`, and leaves URL logging **off**; this fails closed on purpose, because the flag prints secret URLs into the build log.

<br>

## What the plugin does and does not protect

Secret posts are unlisted, not access-controlled. The files are published as ordinary static pages, so anyone holding the URL can read them, and anyone who can read your repository can recompute the URL if they also know the salt.

The plugin does the following on every secret page:

* sets `sitemap: false` so the URL stays out of `jekyll-sitemap` output
* injects `<meta name="robots" content="noindex, nofollow">`
* injects `<meta name="referrer" content="no-referrer">`, so the secret URL is not handed to third parties in the `Referer` header of outbound links, images, or scripts

It cannot protect against the following, which are up to your site:

* **Templates that iterate over all documents.** Search-index generators and "all content" listings usually loop over `site.documents` or `site.collections`, which include secret posts. A template like `{% for d in site.documents %}` will publish every secret URL and title into `search.json`. Exclude the secret collection in any such template.
* **Server-side indexing.** `noindex` is a request; crawlers that ignore it, and anyone with the link, still get the content.
* **Anything requiring real authentication.** If the content must not be readable by a URL holder, this plugin is the wrong tool.

<br>

## Compatibility

### Jekyll Pagination

Secret posts live in a collection, not in `site.posts`, so they are not included in pagination.

### Jekyll Sitemap

Secret documents are set to `sitemap: false`, so they do not appear in the sitemap.

### Jekyll Polyglot

If you use Polyglot for localization and do not plan to support multiple languages for secret posts, add the secret source directory to `exclude_from_localization` in your `_config.yml` so that secret posts are not processed for multiple languages:

```yaml
exclude_from_localization: ["images", "css", "scss", "js", "_secret"]
```

<br>

## Contributions

Contributions are welcome. If you have an improvement or idea, feel free to open a pull request.
