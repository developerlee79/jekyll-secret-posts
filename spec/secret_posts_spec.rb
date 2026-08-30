# frozen_string_literal: true

require "ostruct"
require "tmpdir"
require "fileutils"
require "spec_helper"
require "jekyll/secret_posts/config"
require "jekyll/secret_posts/url_tokenizer"
require "jekyll/secret_posts/generator"
require "jekyll/secret_posts/hooks"

RSpec.describe Jekyll::SecretPosts do
  it "has a version number" do
    expect(Jekyll::SecretPosts).to be_a(Module)
  end
end

RSpec.describe Jekyll::SecretPosts::Config do
  let(:config) { described_class.new(site_config) }

  context "with empty config" do
    let(:site_config) { {} }

    it "uses default source_dir" do
      expect(config.source_dir).to eq("_secret")
    end

    it "uses default collection_name" do
      expect(config.collection_name).to eq("secret")
    end

    it "uses default url_prefix with trailing slash" do
      expect(config.url_prefix).to eq("/s/")
    end

    it "uses empty salt when JEKYLL_SECRET_SALT not set" do
      expect(config.salt).to eq("")
    end

    it "uses default secret_index_layout when not set" do
      expect(config.secret_index_layout).to eq("default")
    end
  end

  context "with JEKYLL_SECRET_SALT set" do
    let(:site_config) { {} }

    around do |example|
      original = ENV.fetch("JEKYLL_SECRET_SALT", nil)
      ENV["JEKYLL_SECRET_SALT"] = "my-secret-salt"
      example.run
    ensure
      ENV["JEKYLL_SECRET_SALT"] = original
    end

    it "reads salt from environment" do
      expect(config.salt).to eq("my-secret-salt")
    end
  end

  context "with custom config" do
    let(:site_config) do
      {
        "secret_posts" => {
          "source_dir" => "_private",
          "collection_name" => "private",
          "url_prefix" => "/p/",
          "index_layout" => "custom_layout"
        }
      }
    end

    it "reads custom source_dir" do
      expect(config.source_dir).to eq("_private")
    end

    it "reads custom collection_name" do
      expect(config.collection_name).to eq("private")
    end

    it "normalizes url_prefix with trailing slash" do
      expect(config.url_prefix).to eq("/p/")
    end

    it "reads custom secret_index_layout" do
      expect(config.secret_index_layout).to eq("custom_layout")
    end
  end

  context "with secret_index_layout set to null" do
    let(:site_config) { { "secret_posts" => { "index_layout" => nil } } }

    it "returns nil for secret_index_layout" do
      expect(config.secret_index_layout).to be_nil
    end
  end

  context "with url_prefix set to empty string" do
    let(:site_config) { { "secret_posts" => { "url_prefix" => "" } } }

    it "falls back to default url_prefix" do
      expect(config.url_prefix).to eq("/s/")
    end
  end

  context "redirect_url" do
    it "returns / when no baseurl or redirect_url" do
      cfg = described_class.new({})
      expect(cfg.redirect_url).to eq("/")
    end

    it "uses baseurl when set and no redirect_url" do
      cfg = described_class.new("baseurl" => "/blog")
      expect(cfg.redirect_url).to eq("/blog/")
    end

    it "uses secret_posts redirect_url when set" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "/custom" })
      expect(cfg.redirect_url).to eq("/custom/")
    end
  end

  context "list_urls?" do
    it "returns false when secret_posts.list_urls is unset" do
      expect(described_class.new({}).list_urls?).to eq(false)
    end

    it "returns true when secret_posts.list_urls is true" do
      cfg = described_class.new("secret_posts" => { "list_urls" => true })
      expect(cfg.list_urls?).to eq(true)
    end

    it "returns false when secret_posts.list_urls is false" do
      cfg = described_class.new("secret_posts" => { "list_urls" => false })
      expect(cfg.list_urls?).to eq(false)
    end

    it "returns false when secret_posts.list_urls is nil" do
      cfg = described_class.new("secret_posts" => { "list_urls" => nil })
      expect(cfg.list_urls?).to eq(false)
    end

    it "returns false when secret_posts.list_urls is empty string" do
      cfg = described_class.new("secret_posts" => { "list_urls" => "" })
      expect(cfg.list_urls?).to eq(false)
    end

    it "returns false when secret_posts.list_urls is whitespace only" do
      cfg = described_class.new("secret_posts" => { "list_urls" => "  " })
      expect(cfg.list_urls?).to eq(false)
    end

    it "returns false for a truthy string, so a quoted value cannot enable URL logging" do
      cfg = described_class.new("secret_posts" => { "list_urls" => "yes" })
      expect(cfg.list_urls?).to eq(false)
    end

    it "returns false for the string \"true\", which YAML did not parse as a boolean" do
      cfg = described_class.new("secret_posts" => { "list_urls" => "true" })
      expect(cfg.list_urls?).to eq(false)
    end
  end

  context "source_dir" do
    it "derives the directory Jekyll actually reads from collection_name" do
      cfg = described_class.new("secret_posts" => { "collection_name" => "private" })
      expect(cfg.source_dir).to eq("_private")
    end

    it "reports a configured source_dir that Jekyll would ignore" do
      cfg = described_class.new("secret_posts" => { "source_dir" => "hidden" })
      expect(cfg.ignored_source_dir).to eq("hidden")
    end

    it "reports nothing when the configured source_dir matches the derived one" do
      cfg = described_class.new("secret_posts" => { "source_dir" => "_secret" })
      expect(cfg.ignored_source_dir).to be_nil
    end

    it "reports nothing when source_dir is unset" do
      expect(described_class.new({}).ignored_source_dir).to be_nil
    end
  end

  context "salt_strength" do
    around do |example|
      original = ENV.fetch("JEKYLL_SECRET_SALT", nil)
      example.run
    ensure
      ENV["JEKYLL_SECRET_SALT"] = original
    end

    it "returns :missing when the salt is unset" do
      ENV["JEKYLL_SECRET_SALT"] = nil
      expect(described_class.new({}).salt_strength).to eq(:missing)
    end

    it "returns :missing when the salt is whitespace only" do
      ENV["JEKYLL_SECRET_SALT"] = "   "
      expect(described_class.new({}).salt_strength).to eq(:missing)
    end

    it "returns :weak when the salt is shorter than the minimum length" do
      ENV["JEKYLL_SECRET_SALT"] = "a" * (described_class::MIN_SALT_LENGTH - 1)
      expect(described_class.new({}).salt_strength).to eq(:weak)
    end

    it "returns :ok when the salt meets the minimum length" do
      ENV["JEKYLL_SECRET_SALT"] = "a" * described_class::MIN_SALT_LENGTH
      expect(described_class.new({}).salt_strength).to eq(:ok)
    end
  end

  context "redirect_url safety" do
    it "rejects a javascript: redirect target and falls back to /" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "javascript:alert(1)" })
      expect(cfg.redirect_url).to eq("/")
    end

    it "rejects a data: redirect target and falls back to /" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "data:text/html,<script>x</script>" })
      expect(cfg.redirect_url).to eq("/")
    end

    it "rejects a protocol-relative redirect target and falls back to /" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "//evil.example.com" })
      expect(cfg.redirect_url).to eq("/")
    end

    it "rejects a relative target that is not rooted and falls back to /" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "evil.example.com" })
      expect(cfg.redirect_url).to eq("/")
    end

    it "allows an https redirect target" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "https://example.com/page" })
      expect(cfg.redirect_url).to eq("https://example.com/page/")
    end

    it "allows a root-relative redirect target" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "/landing" })
      expect(cfg.redirect_url).to eq("/landing/")
    end

    it "falls back to / when the baseurl itself is not a safe target" do
      expect(described_class.new("baseurl" => "javascript:alert(1)").redirect_url).to eq("/")
    end
  end

  context "trailing slash normalization" do
    it "appends a slash to url_prefix that lacks one" do
      cfg = described_class.new("secret_posts" => { "url_prefix" => "/hidden" })
      expect(cfg.url_prefix).to eq("/hidden/")
    end

    it "leaves an already-slashed url_prefix untouched" do
      cfg = described_class.new("secret_posts" => { "url_prefix" => "/hidden/" })
      expect(cfg.url_prefix).to eq("/hidden/")
    end

    it "leaves an already-slashed redirect_url untouched" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "/elsewhere/" })
      expect(cfg.redirect_url).to eq("/elsewhere/")
    end

    it "leaves an already-slashed baseurl untouched" do
      expect(described_class.new("baseurl" => "/blog/").redirect_url).to eq("/blog/")
    end

    it "keeps a redirect_url query string intact" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "/landing?src=x&lang=ko" })
      expect(cfg.redirect_url).to eq("/landing?src=x&lang=ko")
    end

    it "keeps a redirect_url fragment intact" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "https://example.com/page#frag" })
      expect(cfg.redirect_url).to eq("https://example.com/page#frag")
    end

    it "still appends a slash to a plain absolute redirect_url" do
      cfg = described_class.new("secret_posts" => { "redirect_url" => "https://example.com/page" })
      expect(cfg.redirect_url).to eq("https://example.com/page/")
    end

    it "keeps a baseurl query string intact" do
      expect(described_class.new("baseurl" => "/blog?v=1").redirect_url).to eq("/blog?v=1")
    end

    it "normalizes a non-string url_prefix instead of raising" do
      expect(described_class.new("secret_posts" => { "url_prefix" => 5 }).url_prefix).to eq("5/")
    end
  end

  it "no longer exposes token_length" do
    expect(described_class.new({})).not_to respond_to(:token_length)
  end
end

RSpec.describe Jekyll::SecretPosts::UrlTokenizer do
  let(:site_config) { {} }
  let(:config) { Jekyll::SecretPosts::Config.new(site_config) }
  let(:tokenizer) { described_class.new(config) }

  around do |example|
    original = ENV.fetch("JEKYLL_SECRET_SALT", nil)
    ENV["JEKYLL_SECRET_SALT"] = "test-salt"
    example.run
  ensure
    ENV["JEKYLL_SECRET_SALT"] = original
  end

  it "returns same token for same collection and path" do
    token1 = tokenizer.token_for("secret", "foo.md")
    token2 = tokenizer.token_for("secret", "foo.md")
    expect(token1).to eq(token2)
  end

  it "returns different tokens for different paths" do
    token1 = tokenizer.token_for("secret", "foo.md")
    token2 = tokenizer.token_for("secret", "bar.md")
    expect(token1).not_to eq(token2)
  end

  it "returns token of configured length" do
    token = tokenizer.token_for("secret", "foo.md")
    expect(token.length).to eq(32)
  end

  it "returns hex string" do
    token = tokenizer.token_for("secret", "foo.md")
    expect(token).to match(/\A[0-9a-f]+\z/)
  end

  it "handles nil relative_path with deterministic token" do
    token = tokenizer.token_for("secret", nil)
    expect(token.length).to eq(32)
    expect(token).to match(/\A[0-9a-f]+\z/)
    expect(tokenizer.token_for("secret", nil)).to eq(token)
  end

  it "handles nil collection_label with deterministic token" do
    token = tokenizer.token_for(nil, "foo.md")
    expect(token.length).to eq(32)
    expect(token).to match(/\A[0-9a-f]+\z/)
    expect(tokenizer.token_for(nil, "foo.md")).to eq(token)
  end

  it "produces different tokens for different salts" do
    with_salt = tokenizer.token_for("secret", "foo.md")
    ENV["JEKYLL_SECRET_SALT"] = "other-salt"
    expect(described_class.new(config).token_for("secret", "foo.md")).not_to eq(with_salt)
  end

  describe "#url_for" do
    it "wraps the token in the configured url_prefix with a trailing slash" do
      expect(tokenizer.url_for("secret", "foo.md")).to eq("/s/#{tokenizer.token_for('secret', 'foo.md')}/")
    end

    it "uses a custom url_prefix" do
      custom = described_class.new(
        Jekyll::SecretPosts::Config.new("secret_posts" => { "url_prefix" => "/p" })
      )
      expect(custom.url_for("secret", "foo.md")).to match(%r{\A/p/[0-9a-f]{32}/\z})
    end
  end
end

RSpec.describe Jekyll::SecretPosts::Generator do
  let(:pages) { [] }
  let(:site) do
    double(
      "Site",
      config: {
        "secret_posts" => {
          "source_dir" => "_secret",
          "collection_name" => "secret",
          "url_prefix" => "/s/"
        }
      },
      collections: {},
      pages: pages
    )
  end

  before do
    allow(site).to receive(:source).and_return("/tmp/source")
    allow(site).to receive(:in_theme_dir).and_return("/tmp/source")
  end

  it "adds secret index redirect page to site.pages" do
    generator = described_class.new
    generator.generate(site)

    expect(pages.size).to eq(1)
    index_page = pages.first
    expect(index_page.data["permalink"]).to eq("/s/")
    expect(index_page.data["sitemap"]).to eq(false)
    expect(index_page.content).to include("http-equiv=\"refresh\"")
    expect(index_page.content).to include("Redirecting...")
    expect(index_page.content).to include("Go to homepage")
  end

  it "HTML-escapes the redirect url in the generated index page" do
    escaping_site = double(
      "Site",
      config: {
        "secret_posts" => { "url_prefix" => "/s/", "redirect_url" => '/a?x=1&y=2"z' }
      },
      collections: {},
      pages: pages
    )
    allow(escaping_site).to receive(:source).and_return("/tmp/source")
    allow(escaping_site).to receive(:in_theme_dir).and_return("/tmp/source")

    described_class.new.generate(escaping_site)

    content = pages.first.content
    expect(content).to include("&amp;y=2&quot;z")
    expect(content).not_to include('&y=2"z')
  end

  describe "salt warnings" do
    around do |example|
      original = ENV.fetch("JEKYLL_SECRET_SALT", nil)
      example.run
    ensure
      ENV["JEKYLL_SECRET_SALT"] = original
    end

    it "warns when JEKYLL_SECRET_SALT is unset" do
      ENV["JEKYLL_SECRET_SALT"] = nil
      logger = double("logger", info: nil, warn: nil)
      allow(Jekyll).to receive(:logger).and_return(logger)

      described_class.new.generate(site)

      expect(logger).to have_received(:warn).with(/JEKYLL_SECRET_SALT is not set/)
    end

    it "warns when JEKYLL_SECRET_SALT is too short" do
      ENV["JEKYLL_SECRET_SALT"] = "short"
      logger = double("logger", info: nil, warn: nil)
      allow(Jekyll).to receive(:logger).and_return(logger)

      described_class.new.generate(site)

      expect(logger).to have_received(:warn).with(/shorter than/)
    end

    it "does not warn when JEKYLL_SECRET_SALT is strong enough" do
      ENV["JEKYLL_SECRET_SALT"] = "a" * Jekyll::SecretPosts::Config::MIN_SALT_LENGTH
      logger = double("logger", info: nil, warn: nil)
      allow(Jekyll).to receive(:logger).and_return(logger)

      described_class.new.generate(site)

      expect(logger).not_to have_received(:warn)
    end
  end

  context "when secret_posts.list_urls is true" do
    let(:site) do
      double(
        "Site",
        config: {
          "secret_posts" => {
            "source_dir" => "_secret",
            "collection_name" => "secret",
            "url_prefix" => "/s/",
            "list_urls" => true
          }
        },
        collections: {},
        pages: pages
      )
    end

    it "logs to Jekyll.logger.info when no secret collection exists" do
      logger = double("logger", info: nil, warn: nil)
      allow(Jekyll).to receive(:logger).and_return(logger)

      generator = described_class.new
      generator.generate(site)

      expect(logger).to have_received(:info).with(/Secret posts: no collection/)
    end

    it "logs each secret post URL when collection has docs" do
      doc = OpenStruct.new(
        collection: OpenStruct.new(label: "secret"),
        relative_path: "my-post.md"
      )
      collection = double("Collection", docs: [doc])
      site_with_collection = double(
        "Site",
        config: {
          "secret_posts" => {
            "source_dir" => "_secret",
            "collection_name" => "secret",
            "url_prefix" => "/s/",
            "list_urls" => true
          },
          "baseurl" => ""
        },
        collections: { "secret" => collection },
        pages: pages,
        source: "/tmp/source",
        in_theme_dir: "/tmp/source"
      )
      allow(site_with_collection).to receive(:source).and_return("/tmp/source")
      allow(site_with_collection).to receive(:in_theme_dir).and_return("/tmp/source")

      logger = double("logger", info: nil, warn: nil)
      allow(Jekyll).to receive(:logger).and_return(logger)

      original_salt = ENV.fetch("JEKYLL_SECRET_SALT", nil)
      ENV["JEKYLL_SECRET_SALT"] = "test-salt"
      generator = described_class.new
      generator.generate(site_with_collection)
      expect(logger).to have_received(:info).with(%r{Secret post URL: /s/[0-9a-f]+/})
    ensure
      ENV["JEKYLL_SECRET_SALT"] = original_salt
    end
  end
end

RSpec.describe Jekyll::SecretPosts::Hooks do
  describe ".apply_secret_permalink" do
    around do |example|
      original = ENV.fetch("JEKYLL_SECRET_SALT", nil)
      ENV["JEKYLL_SECRET_SALT"] = "test-salt"
      example.run
    ensure
      ENV["JEKYLL_SECRET_SALT"] = original
    end

    it "sets permalink and sitemap on secret collection documents" do
      doc = OpenStruct.new(
        collection: OpenStruct.new(label: "secret"),
        site: OpenStruct.new(config: { "secret_posts" => { "url_prefix" => "/s/" } }),
        relative_path: "my-post.md",
        data: {}
      )

      described_class.apply_secret_permalink(doc)

      expect(doc.data["permalink"]).to match(%r{\A/s/[0-9a-f]{32}/\z})
      expect(doc.data["sitemap"]).to eq(false)
    end
  end

  describe ".register_secret_collection" do
    let(:site) do
      double("Site", config: { "collections" => {} })
    end

    it "adds secret collection to site config" do
      described_class.register_secret_collection(site)
      expect(site.config["collections"]["secret"]).to eq("output" => true)
    end

    it "does not overwrite existing collection" do
      site.config["collections"]["secret"] = { "existing" => true }
      described_class.register_secret_collection(site)
      expect(site.config["collections"]["secret"]).to eq("existing" => true)
    end

    it "un-excludes the directory Jekyll actually reads" do
      excluding_site = double("Site", config: { "collections" => {}, "exclude" => %w[_secret assets] })
      described_class.register_secret_collection(excluding_site)
      expect(excluding_site.config["exclude"]).to eq(["assets"])
    end

    it "leaves an unrelated configured source_dir excluded, so its files stay unpublished" do
      leaky_site = double(
        "Site",
        config: {
          "collections" => {},
          "exclude" => ["hidden"],
          "secret_posts" => { "source_dir" => "hidden" }
        }
      )
      allow(Jekyll).to receive(:logger).and_return(double("logger", warn: nil, info: nil))

      described_class.register_secret_collection(leaky_site)

      expect(leaky_site.config["exclude"]).to eq(["hidden"])
    end

    it "warns when the configured source_dir is not the directory Jekyll reads" do
      logger = double("logger", warn: nil, info: nil)
      allow(Jekyll).to receive(:logger).and_return(logger)
      misconfigured = double(
        "Site",
        config: { "collections" => {}, "secret_posts" => { "source_dir" => "hidden" } }
      )

      described_class.register_secret_collection(misconfigured)

      expect(logger).to have_received(:warn).with(/source_dir "hidden" is ignored/)
    end
  end

  describe ".inject_secret_meta" do
    let(:doc) do
      OpenStruct.new(
        collection: OpenStruct.new(label: "secret"),
        site: OpenStruct.new(config: {}),
        output: "<html><head></head><body>Hi</body></html>"
      )
    end

    it "injects noindex meta after head" do
      described_class.inject_secret_meta(doc)
      expect(doc.output).to include('<meta name="robots" content="noindex, nofollow">')
      expect(doc.output).to include("<head>\n  <meta name=\"robots\"")
    end

    it "injects a no-referrer policy so the secret URL is not leaked in the Referer header" do
      described_class.inject_secret_meta(doc)
      expect(doc.output).to include('<meta name="referrer" content="no-referrer">')
    end

    it "falls back to prepend when no head tag" do
      doc_without_head = OpenStruct.new(
        collection: OpenStruct.new(label: "secret"),
        site: OpenStruct.new(config: {}),
        output: "<html><body>Hi</body></html>"
      )
      described_class.inject_secret_meta(doc_without_head)
      expect(doc_without_head.output).to start_with('<meta name="robots" content="noindex, nofollow">')
      expect(doc_without_head.output).to include('<meta name="referrer" content="no-referrer">')
    end

    it "injects into a head tag that carries attributes" do
      doc_with_attrs = OpenStruct.new(
        collection: OpenStruct.new(label: "secret"),
        site: OpenStruct.new(config: {}),
        output: %(<!DOCTYPE html>\n<html>\n<head prefix="og: https://ogp.me/ns#">\n</head>\n<body></body>\n</html>)
      )
      described_class.inject_secret_meta(doc_with_attrs)

      expect(doc_with_attrs.output).to start_with("<!DOCTYPE html>")
      expect(doc_with_attrs.output).to include(
        %(<head prefix="og: https://ogp.me/ns#">\n  <meta name="robots" content="noindex, nofollow">)
      )
    end

    it "keeps the doctype first so the page does not fall into quirks mode" do
      doc_with_attrs = OpenStruct.new(
        collection: OpenStruct.new(label: "secret"),
        site: OpenStruct.new(config: {}),
        output: %(<!DOCTYPE html>\n<html>\n<head lang="en">\n</head>\n<body></body>\n</html>)
      )
      described_class.inject_secret_meta(doc_with_attrs)

      expect(doc_with_attrs.output.lines.first.strip).to eq("<!DOCTYPE html>")
    end

    it "does not mistake a header element for the head tag" do
      doc_with_header = OpenStruct.new(
        collection: OpenStruct.new(label: "secret"),
        site: OpenStruct.new(config: {}),
        output: "<html><body><header>Title</header></body></html>"
      )
      described_class.inject_secret_meta(doc_with_header)

      expect(doc_with_header.output).to start_with('<meta name="robots" content="noindex, nofollow">')
      expect(doc_with_header.output).to include("<header>Title</header>")
    end

    it "leaves documents outside the secret collection untouched" do
      public_doc = OpenStruct.new(
        collection: OpenStruct.new(label: "posts"),
        site: OpenStruct.new(config: {}),
        output: "<html><head></head><body>Hi</body></html>"
      )
      described_class.inject_secret_meta(public_doc)
      expect(public_doc.output).not_to include("robots")
    end
  end

  describe ".inject_secret_index_meta" do
    it "injects the meta tags into the generated secret index page" do
      page = OpenStruct.new(
        data: { "secret_index" => true },
        output: "<html><head></head><body>Redirecting...</body></html>"
      )
      described_class.inject_secret_index_meta(page)
      expect(page.output).to include('<meta name="robots" content="noindex, nofollow">')
      expect(page.output).to include('<meta name="referrer" content="no-referrer">')
    end

    it "leaves unrelated pages untouched" do
      page = OpenStruct.new(data: {}, output: "<html><head></head><body>Hi</body></html>")
      described_class.inject_secret_index_meta(page)
      expect(page.output).not_to include("robots")
    end
  end
end

RSpec.describe "Secret posts integration" do
  it "outputs secret collection docs under /s/<token>/ not under _secret" do
    Dir.mktmpdir do |tmp|
      source = tmp
      dest = File.join(tmp, "_site")
      FileUtils.mkdir_p(File.join(source, "_secret"))
      File.write(
        File.join(source, "_secret", "test-post.md"),
        "---\ntitle: Secret\n---\nBody\n"
      )
      File.write(
        File.join(source, "_config.yml"),
        "plugins:\n  - jekyll-secret-posts\nsecret_posts:\n  index_layout: null\n"
      )
      config = Jekyll.configuration(
        "source" => source,
        "destination" => dest,
        "plugins" => ["jekyll-secret-posts"]
      )
      site = Jekyll::Site.new(config)
      site.process
      s_dir = File.join(dest, "s")
      expect(File.directory?(s_dir)).to eq(true)
      token_dirs = Dir.children(s_dir).reject { |c| c == "index.html" }
      expect(token_dirs.size).to be >= 1
      token_dirs.each do |token|
        expect(token).to match(/\A[0-9a-f]{32}\z/)
        index_path = File.join(dest, "s", token, "index.html")
        expect(File.file?(index_path)).to eq(true)
      end
      secret_dir = File.join(dest, "_secret")
      expect(File.directory?(secret_dir)).to eq(false)
    end
  end

  it "outputs secret index redirect page at /s/index.html" do
    Dir.mktmpdir do |tmp|
      source = tmp
      dest = File.join(tmp, "_site")
      FileUtils.mkdir_p(File.join(source, "_secret"))
      File.write(
        File.join(source, "_config.yml"),
        "plugins:\n  - jekyll-secret-posts\nsecret_posts:\n  index_layout: null\n"
      )
      config = Jekyll.configuration(
        "source" => source,
        "destination" => dest,
        "plugins" => ["jekyll-secret-posts"]
      )
      site = Jekyll::Site.new(config)
      site.process
      index_path = File.join(dest, "s", "index.html")
      expect(File.file?(index_path)).to eq(true)
      content = File.read(index_path)
      expect(content).to include("http-equiv=\"refresh\"")
      expect(content).to include("0;url=/")
      expect(content).to include("Redirecting...")
      expect(content).to include("Go to homepage")
    end
  end

  it "keeps an excluded non-collection directory out of the build" do
    Dir.mktmpdir do |tmp|
      source = tmp
      dest = File.join(tmp, "_site")
      FileUtils.mkdir_p(File.join(source, "hidden"))
      File.write(
        File.join(source, "hidden", "leak.md"),
        "---\ntitle: Secret\n---\nSENTINEL_BODY\n"
      )
      File.write(
        File.join(source, "_config.yml"),
        "plugins:\n  - jekyll-secret-posts\nexclude: [\"hidden\"]\n" \
        "secret_posts:\n  index_layout: null\n  source_dir: \"hidden\"\n"
      )
      config = Jekyll.configuration(
        "source" => source,
        "destination" => dest,
        "plugins" => ["jekyll-secret-posts"]
      )
      Jekyll::Site.new(config).process

      built = Dir.glob(File.join(dest, "**", "*")).select { |f| File.file?(f) }
      expect(built.map { |f| f.sub(dest, "") }).to eq(["/s/index.html"])
      expect(built.none? { |f| File.read(f).include?("SENTINEL_BODY") }).to eq(true)
    end
  end

  it "marks the secret index page and every secret document as noindex and no-referrer" do
    Dir.mktmpdir do |tmp|
      source = tmp
      dest = File.join(tmp, "_site")
      FileUtils.mkdir_p(File.join(source, "_secret"))
      File.write(
        File.join(source, "_secret", "test-post.md"),
        "---\ntitle: Secret\n---\nBody\n"
      )
      File.write(
        File.join(source, "_config.yml"),
        "plugins:\n  - jekyll-secret-posts\nsecret_posts:\n  index_layout: null\n"
      )
      config = Jekyll.configuration(
        "source" => source,
        "destination" => dest,
        "plugins" => ["jekyll-secret-posts"]
      )
      Jekyll::Site.new(config).process

      html_files = Dir.glob(File.join(dest, "s", "**", "*.html"))
      expect(html_files.size).to eq(2)
      html_files.each do |path|
        content = File.read(path)
        expect(content).to include('<meta name="robots" content="noindex, nofollow">')
        expect(content).to include('<meta name="referrer" content="no-referrer">')
      end
    end
  end

  it "logs a URL matching the actual generated token directory when list_urls is enabled" do
    Dir.mktmpdir do |tmp|
      source = tmp
      dest = File.join(tmp, "_site")
      FileUtils.mkdir_p(File.join(source, "_secret"))
      File.write(
        File.join(source, "_secret", "test-post.md"),
        "---\ntitle: Secret\n---\nBody\n"
      )
      File.write(
        File.join(source, "_config.yml"),
        "plugins:\n  - jekyll-secret-posts\nsecret_posts:\n  index_layout: null\n  list_urls: true\n"
      )
      config = Jekyll.configuration(
        "source" => source,
        "destination" => dest,
        "plugins" => ["jekyll-secret-posts"]
      )

      logged = []
      real_logger = Jekyll.logger
      allow(real_logger).to receive(:info) { |*args| logged << args.join(" ") }

      site = Jekyll::Site.new(config)
      site.process

      secret_urls = logged.grep(/Secret post URL:/)
      expect(secret_urls.size).to eq(1)

      logged_token = secret_urls.first[%r{/s/([0-9a-f]{32})/}, 1]
      expect(logged_token).not_to be_nil

      written_tokens = Dir.children(File.join(dest, "s")).reject { |c| c == "index.html" }
      expect(written_tokens).to eq([logged_token])
    end
  end
end
