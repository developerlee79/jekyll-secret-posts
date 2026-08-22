# frozen_string_literal: true

require "jekyll"
require "jekyll/secret_posts/config"
require "jekyll/secret_posts/url_tokenizer"
require "jekyll/secret_posts/generator"
require "jekyll/secret_posts/hooks"

Jekyll::SecretPosts::Hooks.register
