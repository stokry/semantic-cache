# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Cache do
  let(:base_embedding) { test_embedding(1) }
  let(:similar_emb) { similar_embedding(base_embedding, noise: 0.005) }
  let(:different_emb) { different_embedding(base_embedding) }

  before do
    SemanticCache.configure do |c|
      c.openai_api_key = "test-key"
    end
  end

  describe "#fetch" do
    it "calls the block on cache miss" do
      stub_embedding_request(embedding: base_embedding)

      cache = described_class.new
      result = cache.fetch("What is Ruby?") { "A programming language" }

      expect(result).to eq("A programming language")
      expect(cache.current_stats[:misses]).to eq(1)
    end

    it "returns cached response on semantic match" do
      call_count = 0

      # First call: returns base_embedding
      # Second call: returns similar embedding (should match)
      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .to_return(
          { status: 200, body: { object: "list", data: [{ object: "embedding", index: 0, embedding: base_embedding }], model: "text-embedding-3-small", usage: { prompt_tokens: 5, total_tokens: 5 } }.to_json, headers: { "Content-Type" => "application/json" } },
          { status: 200, body: { object: "list", data: [{ object: "embedding", index: 0, embedding: similar_emb }], model: "text-embedding-3-small", usage: { prompt_tokens: 5, total_tokens: 5 } }.to_json, headers: { "Content-Type" => "application/json" } }
        )

      cache = described_class.new

      cache.fetch("What is Ruby?") do
        call_count += 1
        "A programming language"
      end

      result = cache.fetch("Tell me about Ruby") do
        call_count += 1
        "This should not be called"
      end

      expect(result).to eq("A programming language")
      expect(call_count).to eq(1)
      expect(cache.current_stats[:hits]).to eq(1)
    end

    it "calls the block when queries are semantically different" do
      call_count = 0

      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .to_return(
          { status: 200, body: { object: "list", data: [{ object: "embedding", index: 0, embedding: base_embedding }], model: "text-embedding-3-small", usage: { prompt_tokens: 5, total_tokens: 5 } }.to_json, headers: { "Content-Type" => "application/json" } },
          { status: 200, body: { object: "list", data: [{ object: "embedding", index: 0, embedding: different_emb }], model: "text-embedding-3-small", usage: { prompt_tokens: 5, total_tokens: 5 } }.to_json, headers: { "Content-Type" => "application/json" } }
        )

      cache = described_class.new

      cache.fetch("What is Ruby?") do
        call_count += 1
        "A programming language"
      end

      cache.fetch("What is the weather today?") do
        call_count += 1
        "It's sunny"
      end

      expect(call_count).to eq(2)
      expect(cache.current_stats[:misses]).to eq(2)
    end

    it "requires a block" do
      stub_embedding_request
      cache = described_class.new
      expect { cache.fetch("test") }.to raise_error(ArgumentError, "A block is required")
    end

    it "tracks cost savings" do
      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .to_return(
          { status: 200, body: { object: "list", data: [{ object: "embedding", index: 0, embedding: base_embedding }], model: "text-embedding-3-small", usage: { prompt_tokens: 5, total_tokens: 5 } }.to_json, headers: { "Content-Type" => "application/json" } },
          { status: 200, body: { object: "list", data: [{ object: "embedding", index: 0, embedding: similar_emb }], model: "text-embedding-3-small", usage: { prompt_tokens: 5, total_tokens: 5 } }.to_json, headers: { "Content-Type" => "application/json" } }
        )

      cache = described_class.new
      cache.fetch("q1", model: "gpt-4o") { "answer" }
      cache.fetch("q2", model: "gpt-4o") { "should not run" }

      expect(cache.current_stats[:total_savings]).to be > 0
    end
  end

  describe "#fetch_openai / #fetch_anthropic / #fetch_gemini" do
    it "delegates to fetch with correct model" do
      stub_embedding_request(embedding: base_embedding)
      cache = described_class.new

      cache.fetch_openai("test") { "openai response" }
      cache.fetch_anthropic("test2") { "anthropic response" }
      cache.fetch_gemini("test3") { "gemini response" }

      expect(cache.current_stats[:total_queries]).to eq(3)
    end
  end

  describe "#invalidate" do
    it "removes entries by tags" do
      stub_embedding_request(embedding: base_embedding)
      cache = described_class.new

      cache.fetch("q1", tags: [:product]) { "answer1" }
      expect(cache.size).to eq(1)

      cache.invalidate(tags: [:product])
      expect(cache.size).to eq(0)
    end
  end

  describe "#clear" do
    it "removes all entries and resets stats" do
      stub_embedding_request(embedding: base_embedding)
      cache = described_class.new

      cache.fetch("q1") { "a1" }
      cache.clear

      expect(cache.size).to eq(0)
      expect(cache.current_stats[:total_queries]).to eq(0)
    end
  end

  describe "#savings_report" do
    it "returns a formatted string" do
      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .to_return(
          { status: 200, body: { object: "list", data: [{ object: "embedding", index: 0, embedding: base_embedding }], model: "text-embedding-3-small", usage: { prompt_tokens: 5, total_tokens: 5 } }.to_json, headers: { "Content-Type" => "application/json" } },
          { status: 200, body: { object: "list", data: [{ object: "embedding", index: 0, embedding: similar_emb }], model: "text-embedding-3-small", usage: { prompt_tokens: 5, total_tokens: 5 } }.to_json, headers: { "Content-Type" => "application/json" } }
        )

      cache = described_class.new
      cache.fetch("q1", model: "gpt-4o") { "answer" }
      cache.fetch("q2", model: "gpt-4o") { "cached" }

      report = cache.savings_report
      expect(report).to include("Total saved:")
      expect(report).to include("1 cached calls")
    end
  end

  describe "custom store" do
    it "accepts a duck-typed store object" do
      custom = SemanticCache::Stores::Memory.new
      stub_embedding_request(embedding: base_embedding)

      cache = described_class.new(store: custom)
      cache.fetch("test") { "result" }

      expect(custom.size).to eq(1)
    end

    it "raises on invalid store type" do
      expect { described_class.new(store: :invalid) }.to raise_error(SemanticCache::ConfigurationError)
    end
  end
end
