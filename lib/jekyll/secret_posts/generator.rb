# frozen_string_literal: true

require "cgi"
require "jekyll/secret_posts/config"
require "jekyll/secret_posts/hooks"
require "jekyll/secret_posts/url_tokenizer"

module Jekyll
  module SecretPosts
    class Generator < Jekyll::Generator
      safe true
      priority :high

      def generate(site)
        config = Config.new(site.config)
        add_secret_index_page(site, config)
        log_secret_urls(site, config) if config.list_urls?
      end

      private

      def add_secret_index_page(site, config)
        prefix_dir = config.url_prefix.gsub(%r{\A/|/\z}, "")
        page = Jekyll::PageWithoutAFile.new(site, site.source, prefix_dir, "index.html")
        page.data["permalink"] = config.url_prefix
        page.data["sitemap"] = false
        page.data[Hooks::SECRET_INDEX_FLAG] = true
        assign_redirect_content(page, config)
        site.pages << page
      end

      def assign_redirect_content(page, config)
        url = CGI.escapeHTML(config.redirect_url)
        if config.secret_index_layout
          page.data["layout"] = config.secret_index_layout
          page.content = redirect_fragment(url)
        else
          page.data["layout"] = nil
          page.content = redirect_standalone_html(url)
        end
      end

      def redirect_fragment(url)
        <<~FRAGMENT.strip
          <meta http-equiv="refresh" content="0;url=#{url}">
          <p>Redirecting...</p>
          <p><a href="#{url}">Go to homepage</a></p>
        FRAGMENT
      end

      def redirect_standalone_html(url)
        <<~HTML.strip
          <!DOCTYPE html>
          <html>
          <head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=#{url}"></head>
          <body><p>Redirecting...</p><p><a href="#{url}">Go to homepage</a></p></body>
          </html>
        HTML
      end

      def log_secret_urls(site, config)
        collection = site.collections[config.collection_name]
        unless collection
          Jekyll.logger.info "Secret posts: no collection '#{config.collection_name}'"
          return
        end
        docs = collection.docs
        if docs.empty?
          Jekyll.logger.info "Secret posts: no documents"
          return
        end
        log_secret_doc_urls(docs, config, site)
      end

      def log_secret_doc_urls(docs, config, site)
        tokenizer = UrlTokenizer.new(config)
        baseurl = normalized_baseurl(site.config["baseurl"])
        docs.each { |doc| log_one_secret_url(doc, tokenizer, baseurl) }
      end

      def normalized_baseurl(baseurl_value)
        baseurl = baseurl_value.to_s.strip
        baseurl.empty? ? nil : baseurl
      end

      def log_one_secret_url(doc, tokenizer, baseurl)
        path = tokenizer.url_for(doc.collection.label, doc.relative_path)
        full_url = baseurl ? "#{baseurl.sub(%r{/\z}, '')}#{path}" : path
        Jekyll.logger.info "Secret post URL: #{full_url}"
      end
    end
  end
end
