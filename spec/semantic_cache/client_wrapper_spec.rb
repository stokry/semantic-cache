# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::ClientWrapper do
  let(:base_embedding) { test_embedding(1) }
  let(:similar_emb) { similar_embedding(base_embedding, noise: 0.005) }

  before do
    SemanticCache.configure do |c|
      c.openai_api_key = "test-key"
    end
  end

  describe "#chat" do
    it "caches chat responses based on user message" do
      call_count = 0

      fake_client = double("OpenAI::Client")
      allow(fake_client).to receive(:chat) do
        call_count += 1
        { "choices" => [{ "message" => { "content" => "Paris" } }] }
      end

      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .to_return(
          { status: 200, body: { object: "list", data: [{ object: "embedding", index: 0, embedding: base_embedding }], model: "text-embedding-3-small", usage: { prompt_tokens: 5, total_tokens: 5 } }.to_json, headers: { "Content-Type" => "application/json" } },
          { status: 200, body: { object: "list", data: [{ object: "embedding", index: 0, embedding: similar_emb }], model: "text-embedding-3-small", usage: { prompt_tokens: 5, total_tokens: 5 } }.to_json, headers: { "Content-Type" => "application/json" } }
        )

      cached = described_class.new(fake_client)

      cached.chat(parameters: {
        model: "gpt-4o",
        messages: [{ role: "user", content: "Capital of France?" }]
      })

      cached.chat(parameters: {
        model: "gpt-4o",
        messages: [{ role: "user", content: "What is France's capital?" }]
      })

      expect(call_count).to eq(1)
    end

    it "passes through calls without user messages" do
      fake_client = double("OpenAI::Client")
      expect(fake_client).to receive(:chat).and_return("response")

      cached = described_class.new(fake_client)
      result = cached.chat(parameters: {
        model: "gpt-4o",
        messages: [{ role: "system", content: "You are helpful" }]
      })

      expect(result).to eq("response")
    end
  end

  describe "#semantic_cache" do
    it "exposes the underlying cache" do
      fake_client = double("OpenAI::Client")
      cached = described_class.new(fake_client)

      expect(cached.semantic_cache).to be_a(SemanticCache::Cache)
    end
  end

  describe "method delegation" do
    it "delegates unknown methods to the wrapped client" do
      fake_client = double("OpenAI::Client")
      allow(fake_client).to receive(:models).and_return("models list")

      cached = described_class.new(fake_client)
      expect(cached.models).to eq("models list")
    end

    it "raises NoMethodError for truly unknown methods" do
      fake_client = double("OpenAI::Client")
      cached = described_class.new(fake_client)
      expect { cached.nonexistent_method }.to raise_error(NoMethodError)
    end
  end
end
