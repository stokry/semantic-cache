# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Configuration do
  let(:config) { described_class.new }

  describe "defaults" do
    it "has a default similarity threshold of 0.85" do
      expect(config.similarity_threshold).to eq(0.85)
    end

    it "has a default embedding model" do
      expect(config.embedding_model).to eq("text-embedding-3-small")
    end

    it "defaults to memory store" do
      expect(config.store).to eq(:memory)
    end

    it "has no default TTL" do
      expect(config.default_ttl).to be_nil
    end

    it "tracks costs by default" do
      expect(config.track_costs).to be true
    end

    it "defaults to openai embedding adapter" do
      expect(config.embedding_adapter).to eq(:openai)
    end

    it "has a default embedding timeout of 30 seconds" do
      expect(config.embedding_timeout).to eq(30)
    end

    it "has no default max cache size" do
      expect(config.max_cache_size).to be_nil
    end
  end

  describe "#cost_for" do
    it "returns known model costs" do
      cost = config.cost_for("gpt-4o")
      expect(cost[:input]).to eq(0.005)
      expect(cost[:output]).to eq(0.015)
    end

    it "returns default costs for unknown models" do
      cost = config.cost_for("unknown-model-x")
      expect(cost[:input]).to eq(0.001)
      expect(cost[:output]).to eq(0.002)
    end
  end

  describe "custom values" do
    it "allows setting embedding_timeout" do
      config.embedding_timeout = 60
      expect(config.embedding_timeout).to eq(60)
    end

    it "allows setting max_cache_size" do
      config.max_cache_size = 1000
      expect(config.max_cache_size).to eq(1000)
    end

    it "allows disabling timeout with nil" do
      config.embedding_timeout = nil
      expect(config.embedding_timeout).to be_nil
    end

    it "allows setting embedding_adapter to :ruby_llm" do
      config.embedding_adapter = :ruby_llm
      expect(config.embedding_adapter).to eq(:ruby_llm)
    end
  end
end
