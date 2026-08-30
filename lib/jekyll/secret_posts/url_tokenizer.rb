# frozen_string_literal: true

require "digest"

module Jekyll
  module SecretPosts
    class UrlTokenizer
      TOKEN_LENGTH = 32

      def initialize(config)
        @config = config
      end

      # A compatibility contract, not an implementation detail: a secret post has
      # no address other than its token, so changing this breaks every URL already
      # shared. Pinned by golden vectors in the spec. Two weaknesses are accepted
      # to keep it stable, neither reachable by an outsider:
      #   * salt-prefixed digest rather than HMAC -- truncating to 128 of 256 bits
      #     leaves too little state for a length-extension attack.
      #   * no field separator, so ("sec", "retfoo.md") collides with
      #     ("secret", "foo.md") -- both operands are the site's own.
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
