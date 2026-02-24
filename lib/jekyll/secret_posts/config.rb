# frozen_string_literal: true

module Jekyll
  module SecretPosts
    class Config
      DEFAULT_SOURCE_DIR = "_secret"
      DEFAULT_COLLECTION_NAME = "secret"
      DEFAULT_URL_PREFIX = "/s/"
      DEFAULT_INDEX_LAYOUT = "default"
      TOKEN_LENGTH = 32

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
        prefix.end_with?("/") ? prefix : "#{prefix}/"
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
        return custom.end_with?("/") ? custom : "#{custom}/" unless custom.empty?

        base = @site_config["baseurl"].to_s.strip
        if base.empty?
          "/"
        else
          base.end_with?("/") ? base : "#{base}/"
        end
      end

      def token_length
        TOKEN_LENGTH
      end

      def list_urls?
        value = @secret_posts["list_urls"]
        !value.nil? && value != false && value.to_s.strip != ""
      end
    end
  end
end
