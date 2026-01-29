# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Embedding do
  before do
    SemanticCache.configure do |c|
      c.openai_api_key = "test-key"
    end
  end

  describe "#generate" do
    it "returns an embedding vector" do
      expected = Array.new(1536) { 0.1 }
      stub_embedding_request(embedding: expected)

      embedding = described_class.new
      result = embedding.generate("What is Ruby?")

      expect(result).to eq(expected)
      expect(result.length).to eq(1536)
    end

    it "raises on API failure" do
      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .to_return(status: 200, body: { error: "bad request" }.to_json, headers: { "Content-Type" => "application/json" })

      embedding = described_class.new
      expect { embedding.generate("test") }.to raise_error(SemanticCache::Error)
    end
  end

  describe "#generate_batch" do
    it "returns multiple embedding vectors" do
      emb1 = Array.new(1536) { 0.1 }
      emb2 = Array.new(1536) { 0.2 }

      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .to_return(
          status: 200,
          body: {
            object: "list",
            data: [
              { object: "embedding", index: 0, embedding: emb1 },
              { object: "embedding", index: 1, embedding: emb2 }
            ],
            model: "text-embedding-3-small",
            usage: { prompt_tokens: 10, total_tokens: 10 }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      embedding = described_class.new
      result = embedding.generate_batch(["text1", "text2"])

      expect(result.length).to eq(2)
      expect(result[0]).to eq(emb1)
      expect(result[1]).to eq(emb2)
    end
  end
end
