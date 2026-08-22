# frozen_string_literal: true

require "digest"

module Jekyll
  module SecretPosts
    class UrlTokenizer
      TOKEN_LENGTH = 32

      def initialize(config)
        @config = config
      end

      def token_for(collection_label, relative_path)
        identifier = "#{collection_label}#{relative_path}"
        raw = Digest::SHA256.hexdigest(@config.salt + identifier)
        raw[0, TOKEN_LENGTH]
      end

      def url_for(collection_label, relative_path)
        "#{@config.url_prefix}#{token_for(collection_label, relative_path)}/"
      end
    end
  end
end
