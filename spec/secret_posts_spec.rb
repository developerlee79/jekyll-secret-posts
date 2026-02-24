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
      logger = double("logger", info: nil)
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
      collection = double("Collection", docs: [doc], read: nil)
      allow(collection).to receive(:respond_to?).with(:read).and_return(true)
      allow(collection).to receive(:respond_to?).with(:directory).and_return(false)
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

      logger = double("logger", info: nil)
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
      expect(site.config["collections"]["secret"]).to eq(
        "output" => true,
        "source" => "_secret"
      )
    end

    it "does not overwrite existing collection" do
      site.config["collections"]["secret"] = { "existing" => true }
      described_class.register_secret_collection(site)
      expect(site.config["collections"]["secret"]).to eq("existing" => true)
    end
  end

  describe ".inject_noindex" do
    let(:doc) do
      OpenStruct.new(
        collection: OpenStruct.new(label: "secret"),
        site: OpenStruct.new(config: {}),
        output: "<html><head></head><body>Hi</body></html>"
      )
    end

    it "injects noindex meta after head" do
      described_class.inject_noindex(doc)
      expect(doc.output).to include('<meta name="robots" content="noindex, nofollow">')
      expect(doc.output).to include("<head>\n  <meta name=\"robots\"")
    end

    it "falls back to prepend when no head tag" do
      doc_without_head = OpenStruct.new(
        collection: OpenStruct.new(label: "secret"),
        site: OpenStruct.new(config: {}),
        output: "<html><body>Hi</body></html>"
      )
      described_class.inject_noindex(doc_without_head)
      expect(doc_without_head.output).to start_with('<meta name="robots" content="noindex, nofollow">')
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
end
