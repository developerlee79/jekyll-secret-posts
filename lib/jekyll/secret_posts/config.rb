# frozen_string_literal: true

module Jekyll
  module SecretPosts
    class Config
      DEFAULT_SOURCE_DIR = "_secret"
      DEFAULT_COLLECTION_NAME = "secret"
      DEFAULT_URL_PREFIX = "/s/"
      DEFAULT_INDEX_LAYOUT = "default"

      def initialize(site_config)
        @site_config = site_config
        @secret_posts = site_config["secret_posts"] || {}
      end

      def source_dir
        @secret_posts["source_dir"] || DEFAULT_SOURCE_DIR
      end

      def collection_name
        @secret_posts["collection_name"] || DEFAULT_COLLECTION_NAME
      end

      def url_prefix
        prefix = @secret_posts["url_prefix"] || DEFAULT_URL_PREFIX
        prefix = DEFAULT_URL_PREFIX if prefix.to_s.strip.empty?
        ensure_trailing_slash(prefix)
      end

      def salt
        ENV["JEKYLL_SECRET_SALT"].to_s
      end

      def secret_index_layout
        return DEFAULT_INDEX_LAYOUT unless @secret_posts.key?("index_layout")

        layout = @secret_posts["index_layout"]
        return nil if layout.nil? || layout == false

        layout.to_s.empty? ? DEFAULT_INDEX_LAYOUT : layout.to_s
      end

      def redirect_url
        custom = @secret_posts["redirect_url"].to_s.strip
        return normalize_redirect_target(custom) unless custom.empty?

        base = @site_config["baseurl"].to_s.strip
        base.empty? ? "/" : normalize_redirect_target(base)
      end

      def list_urls?
        value = @secret_posts["list_urls"]
        return false unless value

        value.to_s.strip != ""
      end

      private

      def ensure_trailing_slash(value)
        str = value.to_s
        str.end_with?("/") ? str : "#{str}/"
      end

      # A query string or fragment is not a directory path, so appending a slash
      # would point at a different target ("/a?b=1" -> "/a?b=1/").
      def normalize_redirect_target(value)
        return value if value.include?("?") || value.include?("#")

        ensure_trailing_slash(value)
      end
    end
  end
end
