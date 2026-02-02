# frozen_string_literal: true

require_relative "lib/semantic_cache/version"

Gem::Specification.new do |spec|
  spec.name = "semantic-cache"
  spec.version = SemanticCache::VERSION
  spec.authors = ["stokry"]
  spec.email = ["stokry@users.noreply.github.com"]

  spec.summary = "Semantic caching for LLM API calls — save 70%+ on costs"
  spec.description = "Cache LLM responses using semantic similarity matching. " \
                     "Similar questions return cached answers instantly, " \
                     "cutting API costs by 70% or more. Works with OpenAI, Anthropic, and Gemini."
  spec.homepage = "https://github.com/stokry/semantic-cache"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/stokry/semantic-cache"
  spec.metadata["changelog_uri"] = "https://github.com/stokry/semantic-cache/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mcp_server_uri"] = "https://rubygems.org/gems/semantic-cache"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?("spec/", "test/", ".git", ".github", "bin/", "examples/")
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Embedding provider adapters (at least one is required)
  # ruby-openai is loaded by default; ruby_llm is optional
  spec.add_dependency "ruby-openai", "~> 7.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "redis", ">= 4.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  # Optional: add ruby_llm to your Gemfile for the :ruby_llm adapter
  # gem "ruby_llm", ">= 1.0"
end
