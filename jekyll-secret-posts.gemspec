# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "jekyll-secret-posts"
  spec.version       = "0.1.0"
  spec.authors       = ["Author"]
  spec.email         = [""]

  spec.summary       = "Jekyll plugin for unlisted posts served at hashed, share-only URLs."
  spec.homepage      = "https://github.com/developerlee79/jekyll-secret-posts"
  spec.required_ruby_version = ">= 2.7.0"
  spec.licenses = ["MIT"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*"] + %w[README.md LICENSE]
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", "~> 4.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
