# frozen_string_literal: true

require "jekyll/secret_posts/config"
require "jekyll/secret_posts/url_tokenizer"

module Jekyll
  module SecretPosts
    module Hooks
      NOINDEX_META = '<meta name="robots" content="noindex, nofollow">'

      # Without this the secret URL travels in the Referer header of every outbound
      # link, image, and script, handing it to parties never given the link.
      NO_REFERRER_META = '<meta name="referrer" content="no-referrer">'

      SECRET_META = [NOINDEX_META, NO_REFERRER_META].freeze

      # Themes routinely open the head with attributes (`<head prefix="og: ...">`),
      # which a literal "<head>" match misses. The lookahead spares <header>, and
      # quoted runs are matched whole so a ">" inside an attribute value does not
      # end the tag early.
      HEAD_TAG = /<head(?=[\s>])(?:[^>"']|"[^"]*"|'[^']*')*>/i.freeze

      SECRET_INDEX_FLAG = "secret_index"

      def self.register
        Jekyll::Hooks.register(:site, :after_init) do |site|
          register_secret_collection(site)
        end
        Jekyll::Hooks.register(:documents, :post_init) do |doc|
          apply_secret_permalink(doc)
        end
        Jekyll::Hooks.register(:documents, :post_render) do |doc|
          inject_secret_meta(doc)
        end
        Jekyll::Hooks.register(:pages, :post_render) do |page|
          inject_secret_index_meta(page)
        end
      end

      def self.register_secret_collection(site)
        config = Config.new(site.config)
        warn_about_ignored_source_dir(config)
        collections = site.config["collections"] ||= {}
        return if collections.key?(config.collection_name)

        collections[config.collection_name] = { "output" => true }
        # Only ever the derived "_<collection_name>": an underscored directory is
        # never served as ordinary content, so un-excluding it publishes nothing new.
        #
        # Must mutate in place: Site#config= aliases this same Array into @exclude
        # before :after_init fires, so reassigning site.config["exclude"] would not
        # reach Site#exclude and the secret source dir would stay excluded.
        exclude = site.config["exclude"]
        exclude.reject! { |e| e.to_s == config.source_dir } if exclude.is_a?(Array)
      end

      def self.warn_about_ignored_source_dir(config)
        ignored = config.ignored_source_dir
        return unless ignored

        Jekyll.logger.warn "Secret posts: source_dir #{ignored.inspect} is ignored. Jekyll reads the " \
                           "secret collection from #{config.source_dir.inspect}; rename the directory " \
                           "or set secret_posts.collection_name instead."
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

      def self.inject_secret_meta(doc)
        return unless secret_config_for(doc)

        doc.output = with_secret_meta(doc.output)
      end

      def self.inject_secret_index_meta(page)
        return unless page.data[SECRET_INDEX_FLAG]

        page.output = with_secret_meta(page.output)
      end

      def self.with_secret_meta(output)
        return output unless output
        # Last resort: prepending puts the tags ahead of the doctype, which means
        # quirks mode and a robots meta outside <head>, where crawlers ignore it.
        return "#{SECRET_META.join("\n")}\n#{output}" unless output.match?(HEAD_TAG)

        meta = SECRET_META.map { |tag| "  #{tag}" }.join("\n")
        output.sub(HEAD_TAG) { |head_tag| "#{head_tag}\n#{meta}" }
      end
    end
  end
end
