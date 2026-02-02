# SemanticCache

**Semantic caching for LLM API calls. Save 70%+ on costs.**

Cache LLM responses using semantic similarity matching. Similar questions return cached answers instantly, cutting API costs dramatically.

```ruby
cache = SemanticCache.new

# First call — hits the API
response = cache.fetch("What's the capital of France?") do
  openai.chat(messages: [{ role: "user", content: "What's the capital of France?" }])
end

# Second call — semantically similar, returns cached response instantly
response = cache.fetch("What is France's capital city?") do
  openai.chat(messages: [{ role: "user", content: "What is France's capital city?" }])
end
# => CACHE HIT! No API call.
```

## Installation

Add to your Gemfile:

```ruby
gem "semantic-cache"
```

Then:

```bash
bundle install
```

Or install directly:

```bash
gem install semantic-cache
```

## Quick Start

```ruby
require "semantic_cache"

# Configure (or set OPENAI_API_KEY env var)
SemanticCache.configure do |c|
  c.openai_api_key = "sk-..."
  c.similarity_threshold = 0.85  # How similar queries must be to match (0.0-1.0)
end

cache = SemanticCache.new

response = cache.fetch("What is Ruby?", model: "gpt-4o") do
  openai.chat(parameters: {
    model: "gpt-4o",
    messages: [{ role: "user", content: "What is Ruby?" }]
  })
end

# Check stats
puts cache.current_stats
# => { hits: 0, misses: 1, hit_rate: 0.0, savings: "$0.00", ... }
```

## How It Works

1. Your query is converted to an embedding vector via the configured embedding adapter (OpenAI or RubyLLM)
2. The cache searches for stored entries with high cosine similarity
3. If a match exceeds the threshold (default 0.85), the cached response is returned
4. If no match, the block executes, and the result is cached for future queries

## Configuration

```ruby
SemanticCache.configure do |c|
  # Similarity threshold (0.0 to 1.0). Higher = stricter matching.
  c.similarity_threshold = 0.85

  # Embedding adapter: :openai (default) or :ruby_llm
  c.embedding_adapter = :openai

  # Embedding model (used by the selected adapter)
  c.embedding_model = "text-embedding-3-small"

  # OpenAI API key (required for :openai adapter)
  c.openai_api_key = ENV["OPENAI_API_KEY"]

  # Default TTL for cached entries (nil = no expiry)
  c.default_ttl = 3600  # 1 hour

  # Cache store: :memory or :redis
  c.store = :memory
  c.store_options = {}  # passed to Redis.new if store is :redis

  # Cost tracking
  c.track_costs = true

  # Timeout for embedding API calls in seconds (default: 30, nil = no timeout)
  c.embedding_timeout = 30

  # Maximum number of entries in the cache (default: nil = unlimited)
  # When exceeded, the oldest entry is evicted automatically.
  c.max_cache_size = 10_000
end
```

## Embedding Adapters

SemanticCache supports multiple embedding providers. Choose the adapter that fits your stack.

### OpenAI (default)

Uses the `ruby-openai` gem. Requires an OpenAI API key.

```ruby
SemanticCache.configure do |c|
  c.embedding_adapter = :openai
  c.embedding_model = "text-embedding-3-small"
  c.openai_api_key = ENV["OPENAI_API_KEY"]
end
```

### RubyLLM

Uses the [ruby_llm](https://github.com/alexrudall/ruby_llm) gem. Supports all embedding providers that RubyLLM supports: **OpenAI**, **Gemini**, **Mistral**, **Ollama**, **Bedrock**, and more — with a single adapter and no OpenAI dependency if you don’t need it.

Add the gem:

```ruby
# Gemfile
gem "ruby_llm"
```

Configure SemanticCache to use the RubyLLM adapter:

```ruby
SemanticCache.configure do |c|
  c.embedding_adapter = :ruby_llm
  c.embedding_model = "text-embedding-3-small"  # or any model your RubyLLM provider supports
end
```

Then configure your embedding provider (API keys, etc.) as required by the [ruby_llm](https://github.com/alexrudall/ruby_llm) gem. If the `ruby_llm` gem is not installed, using `embedding_adapter = :ruby_llm` raises a `SemanticCache::ConfigurationError` with instructions to add the gem.

## Cache Stores

### In-Memory (default)

Thread-safe, no dependencies. Good for development and single-process apps.

```ruby
cache = SemanticCache.new(store: :memory)
```

### Redis

For production, multi-process, and distributed apps. Requires the `redis` gem.

```ruby
gem "redis"
```

```ruby
cache = SemanticCache.new(
  store: :redis,
  store_options: { url: "redis://localhost:6379/0" }
)
```

### Custom Store

Any object that responds to `write`, `entries`, `delete`, `invalidate_by_tags`, `clear`, and `size`:

```ruby
cache = SemanticCache.new(store: MyCustomStore.new)
```

### Cache Size Limits

Both stores support a `max_size` option. When the cache is full, the oldest entry (by creation time) is evicted automatically:

```ruby
# Via constructor
cache = SemanticCache.new(max_size: 5_000)

# Via global configuration
SemanticCache.configure do |c|
  c.max_cache_size = 10_000
end
```

When `max_size` is `nil` (the default), the cache grows without limit.

## TTL & Tag-Based Invalidation

```ruby
# TTL — auto-expires after 1 hour
cache.fetch("Latest news?", ttl: 3600) do
  fetch_news
end

# Tags — group related entries for bulk invalidation
cache.fetch("Ruby version?", tags: [:ruby, :versions]) do
  "3.3.0"
end

cache.fetch("Best framework?", tags: [:ruby, :frameworks]) do
  "Rails"
end

# Invalidate all entries tagged :versions
cache.invalidate(tags: [:versions])
```

## Multi-Model Support

Convenience methods for different LLM providers:

```ruby
cache.fetch_openai("query", model: "gpt-4o") do
  openai.chat(...)
end

cache.fetch_anthropic("query", model: "claude-sonnet-4-20250514") do
  anthropic.messages(...)
end

cache.fetch_gemini("query", model: "gemini-pro") do
  gemini.generate(...)
end
```

## Client Wrapper

Wrap an existing OpenAI client to cache all chat calls automatically:

```ruby
require "openai"

client = OpenAI::Client.new(access_token: "sk-...")
cached_client = SemanticCache.wrap(client)

# All chat calls are now cached
response = cached_client.chat(parameters: {
  model: "gpt-4o",
  messages: [{ role: "user", content: "What is Ruby?" }]
})

# Access cache stats
cached_client.semantic_cache.current_stats

# Other methods are delegated to the original client
cached_client.models  # => calls client.models directly
```

## Cost Tracking & Stats

```ruby
cache = SemanticCache.new

# After some usage...
cache.current_stats
# => {
#   hits: 156,
#   misses: 44,
#   total_queries: 200,
#   hit_rate: 78.0,
#   savings: "$23.45",
#   ...
# }

puts cache.detailed_stats
# Total queries: 200
# Cache hits: 156
# Cache misses: 44
# Hit rate: 78.0%
# Total savings: $23.45

puts cache.savings_report
# Total saved: $23.45 (156 cached calls)
```

Custom model costs:

```ruby
SemanticCache.configure do |c|
  c.model_costs["my-custom-model"] = { input: 0.01, output: 0.03 }
end
```

## Rails Integration

```ruby
# Gemfile
gem "semantic-cache"
```

```ruby
# config/initializers/semantic_cache.rb
require "semantic_cache/rails"

SemanticCache.configure do |c|
  c.openai_api_key = Rails.application.credentials.openai_api_key
  c.store = :redis
  c.store_options = { url: ENV["REDIS_URL"] }
end
```

### Using the Concern

```ruby
class ChatController < ApplicationController
  include SemanticCache::Cacheable

  cache_ai_calls only: [:create], ttl: 1.hour

  def create
    response = SemanticCache.current.fetch(params[:message], model: "gpt-4o") do
      openai_client.chat(parameters: {
        model: "gpt-4o",
        messages: [{ role: "user", content: params[:message] }]
      })
    end

    render json: { response: response }
  end
end
```

### Per-User Namespacing

```ruby
class ApplicationController < ActionController::Base
  around_action :with_semantic_cache

  private

  def with_semantic_cache
    SemanticCache.with_cache(namespace: "user_#{current_user.id}") do
      yield
    end
  end
end
```

## Input Validation

Queries are validated before any API call is made. Passing `nil`, `""`, or whitespace-only strings raises an `ArgumentError` immediately:

```ruby
cache.fetch(nil)   { ... }  # => ArgumentError: query cannot be nil
cache.fetch("")    { ... }  # => ArgumentError: query cannot be blank
cache.fetch("   ") { ... }  # => ArgumentError: query cannot be blank
```

## Embedding Timeout

Embedding API calls are wrapped in a configurable timeout to prevent hanging threads:

```ruby
SemanticCache.configure do |c|
  c.embedding_timeout = 10  # seconds (default: 30)
end
```

If the timeout is exceeded, a `SemanticCache::Error` is raised. Set to `nil` to disable the timeout.

## Demo

Run the built-in demo (no API key needed):

```bash
ruby examples/demo.rb --simulate
```

Or with a real API key:

```bash
OPENAI_API_KEY=sk-... ruby examples/demo.rb
```

## Development

```bash
bundle install
bundle exec rspec
```

## License

MIT License. See [LICENSE](LICENSE).
