# frozen_string_literal: true

require "jekyll/secret_posts/config"
require "jekyll/secret_posts/url_tokenizer"

module Jekyll
  module SecretPosts
    module Hooks
      NOINDEX_META = '<meta name="robots" content="noindex, nofollow">'

      def self.register
        Jekyll::Hooks.register(:site, :after_init) do |site|
          register_secret_collection(site)
        end
        Jekyll::Hooks.register(:documents, :post_init) do |doc|
          apply_secret_permalink(doc)
        end
        Jekyll::Hooks.register(:documents, :post_render) do |doc|
          inject_noindex(doc)
        end
      end

      def self.register_secret_collection(site)
        config = Config.new(site.config)
        collections = site.config["collections"] ||= {}
        return if collections.key?(config.collection_name)

        collections[config.collection_name] = {
          "output" => true,
          "source" => config.source_dir
        }
        exclude = site.config["exclude"]
        exclude.reject! { |e| e.to_s == config.source_dir } if exclude.is_a?(Array)
      end

      def self.apply_secret_permalink(doc)
        return unless secret_document?(doc)

        config = Config.new(doc.site.config)
        tokenizer = UrlTokenizer.new(config)
        token = tokenizer.token_for(doc.collection.label, doc.relative_path)
        doc.data["permalink"] = "#{config.url_prefix}#{token}/"
        doc.data["sitemap"] = false
      end

      def self.secret_document?(doc)
        doc.collection && doc.site &&
          doc.collection.label == Config.new(doc.site.config).collection_name
      end

      def self.inject_noindex(doc)
        return unless doc.collection && doc.site

        config = Config.new(doc.site.config)
        return unless doc.collection.label == config.collection_name
        return unless doc.output

        new_output = if doc.output.include?("<head>")
                       doc.output.sub("<head>", "<head>\n  #{NOINDEX_META}")
                     else
                       "#{NOINDEX_META}\n#{doc.output}"
                     end
        doc.output = new_output
      end
    end
  end
end
