# frozen_string_literal: true

require "jekyll"

module Jekyll
  module SecretPosts
    class Config
      DEFAULT_COLLECTION_NAME = "secret"
      DEFAULT_URL_PREFIX = "/s/"
      DEFAULT_INDEX_LAYOUT = "default"
      DEFAULT_REDIRECT_URL = "/"

      # Below this a salt adds little work for an attacker who already knows the
      # (public) collection name and file path that feed the token.
      MIN_SALT_LENGTH = 16

      # Everything else ("javascript:", "data:", "//host") is rejected.
      SAFE_ABSOLUTE_URL = %r{\Ahttps?://}i.freeze
      # A backslash after the leading slash is excluded too: browsers fold "\"
      # into "/" for special schemes, so "/\host" navigates like "//host".
      ROOT_RELATIVE_URL = %r{\A/(?![/\\])}.freeze

      def initialize(site_config)
        @site_config = site_config
        @secret_posts = site_config["secret_posts"] || {}
      end

      # Derived, not configurable: Jekyll::Collection#relative_directory resolves
      # a collection to "_#{label}" and ignores every other key.
      def source_dir
        "_#{collection_name}"
      end

      # Honouring a mismatched source_dir un-excluded whatever directory it named,
      # publishing a non-underscored one as ordinary site content, secret body and all.
      def ignored_source_dir
        configured = @secret_posts["source_dir"].to_s.strip
        return nil if configured.empty? || configured == source_dir

        configured
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

      def salt_strength
        trimmed = salt.strip
        return :missing if trimmed.empty?
        return :weak if trimmed.length < MIN_SALT_LENGTH

        :ok
      end

      def secret_index_layout
        return DEFAULT_INDEX_LAYOUT unless @secret_posts.key?("index_layout")

        layout = @secret_posts["index_layout"]
        return nil if layout.nil? || layout == false

        layout.to_s.empty? ? DEFAULT_INDEX_LAYOUT : layout.to_s
      end

      def redirect_url
        custom = @secret_posts["redirect_url"].to_s.strip
        return safe_redirect_target(custom, "secret_posts.redirect_url") unless custom.empty?

        base = @site_config["baseurl"].to_s.strip
        base.empty? ? DEFAULT_REDIRECT_URL : safe_redirect_target(base, "baseurl")
      end

      # Strict boolean: this prints secret URLs into the build log, so anything
      # YAML did not parse as `true` (the string "true", say) must not enable it.
      def list_urls?
        @secret_posts["list_urls"] == true
      end

      private

      def safe_redirect_target(value, source_key)
        return normalize_redirect_target(value) if redirect_target_allowed?(value)

        Jekyll.logger.warn "Secret posts: ignoring unsafe #{source_key} #{value.inspect}; " \
                           "using #{DEFAULT_REDIRECT_URL.inspect} instead"
        DEFAULT_REDIRECT_URL
      end

      def redirect_target_allowed?(value)
        value.match?(SAFE_ABSOLUTE_URL) || value.match?(ROOT_RELATIVE_URL)
      end

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
