# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

require "semantic_cache"
require "webmock/rspec"

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random

  config.before(:each) do
    SemanticCache.reset!
  end
end

# Helpers

def stub_embedding_request(input: anything, embedding: nil)
  embedding ||= Array.new(1536) { rand(-1.0..1.0) }

  stub_request(:post, "https://api.openai.com/v1/embeddings")
    .to_return(
      status: 200,
      body: {
        object: "list",
        data: [{ object: "embedding", index: 0, embedding: embedding }],
        model: "text-embedding-3-small",
        usage: { prompt_tokens: 5, total_tokens: 5 }
      }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
end

def stub_embedding_request_with(embeddings_map)
  stub_request(:post, "https://api.openai.com/v1/embeddings")
    .to_return do |request|
      body = JSON.parse(request.body)
      input = body["input"]
      embedding = embeddings_map[input] || Array.new(1536) { rand(-1.0..1.0) }

      {
        status: 200,
        body: {
          object: "list",
          data: [{ object: "embedding", index: 0, embedding: embedding }],
          model: "text-embedding-3-small",
          usage: { prompt_tokens: 5, total_tokens: 5 }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      }
    end
end

# Generate a consistent embedding vector for testing.
# Two calls with the same seed produce the same vector.
def test_embedding(seed = 42, dimensions: 1536)
  rng = Random.new(seed)
  Array.new(dimensions) { rng.rand(-1.0..1.0) }
end

# Generate an embedding that is similar to another (high cosine similarity).
def similar_embedding(base, noise: 0.01)
  base.map { |v| v + rand(-noise..noise) }
end

# Generate an embedding that is very different from another.
def different_embedding(base)
  base.map { |v| -v + rand(-0.5..0.5) }
end
