# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "jekyll-secret-posts"
  spec.version       = "0.1.1"
  spec.authors       = ["devl79"]
  spec.email         = ["developerlee79@users.noreply.github.com"]

  spec.summary       = "Jekyll plugin for unlisted posts served at hashed, share-only URLs."
  spec.homepage      = "https://github.com/developerlee79/jekyll-secret-posts"
  spec.required_ruby_version = ">= 2.7.0"
  spec.licenses = ["MIT"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  spec.files = Dir["lib/**/*"].select { |path| File.file?(path) } + %w[README.md LICENSE CHANGELOG.md]
  spec.require_paths = ["lib"]

  spec.add_dependency "jekyll", "~> 4.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
