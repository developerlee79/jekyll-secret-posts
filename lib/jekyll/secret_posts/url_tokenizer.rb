# frozen_string_literal: true

require "digest"

module Jekyll
  module SecretPosts
    class UrlTokenizer
      def initialize(config)
        @config = config
      end

      def token_for(collection_label, relative_path)
        identifier = "#{collection_label}#{relative_path}"
        raw = Digest::SHA256.hexdigest(@config.salt + identifier)
        raw[0, @config.token_length]
      end
    end
  end
end
