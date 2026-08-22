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
        # Must mutate in place: Site#config= aliases this same Array into @exclude
        # before :after_init fires, so reassigning site.config["exclude"] would not
        # reach Site#exclude and the secret source dir would stay excluded.
        exclude = site.config["exclude"]
        exclude.reject! { |e| e.to_s == config.source_dir } if exclude.is_a?(Array)
      end

      def self.apply_secret_permalink(doc)
        config = secret_config_for(doc)
        return unless config

        doc.data["permalink"] = UrlTokenizer.new(config).url_for(doc.collection.label, doc.relative_path)
        doc.data["sitemap"] = false
      end

      # Returns the Config when doc belongs to the secret collection, otherwise nil.
      def self.secret_config_for(doc)
        return nil unless doc.collection && doc.site

        config = Config.new(doc.site.config)
        config.collection_name == doc.collection.label ? config : nil
      end

      def self.inject_noindex(doc)
        return unless secret_config_for(doc)
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
