# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Adapters::OpenAI do
  before do
    SemanticCache.configure do |c|
      c.openai_api_key = "test-key"
    end
  end

  describe "#generate" do
    it "returns an embedding vector" do
      expected = Array.new(1536) { 0.1 }
      stub_embedding_request(embedding: expected)

      adapter = described_class.new
      result = adapter.generate("What is Ruby?")

      expect(result).to eq(expected)
      expect(result.length).to eq(1536)
    end

    it "raises on API failure" do
      stub_request(:post, "https://api.openai.com/v1/embeddings")
        .to_return(status: 200, body: { error: "bad request" }.to_json, headers: { "Content-Type" => "application/json" })

      adapter = described_class.new
      expect { adapter.generate("test") }.to raise_error(SemanticCache::Error)
    end

    context "input validation" do
      it "raises ArgumentError for nil input" do
        adapter = described_class.new
        expect { adapter.generate(nil) }.to raise_error(ArgumentError, /cannot be nil/)
      end

      it "raises ArgumentError for empty string" do
        adapter = described_class.new
        expect { adapter.generate("") }.to raise_error(ArgumentError, /cannot be blank/)
      end

      it "raises ArgumentError for whitespace-only string" do
        adapter = described_class.new
        expect { adapter.generate("   ") }.to raise_error(ArgumentError, /cannot be blank/)
      end
    end

    context "timeout" do
      it "wraps API call in a timeout" do
        SemanticCache.configure { |c| c.embedding_timeout = 5 }

        stub_request(:post, "https://api.openai.com/v1/embeddings")
          .to_return do
            sleep(10)
            { status: 200, body: {}.to_json }
          end

        adapter = described_class.new
        expect { adapter.generate("test") }.to raise_error(SemanticCache::Error, /timed out/)
      end

      it "respects the configured timeout value" do
        SemanticCache.configure { |c| c.embedding_timeout = 30 }
        adapter = described_class.new
        expect(adapter.instance_variable_get(:@timeout)).to eq(30)
      end

      it "skips timeout when set to nil" do
        SemanticCache.configure { |c| c.embedding_timeout = nil }

        expected = Array.new(1536) { 0.1 }
        stub_embedding_request(embedding: expected)

        adapter = described_class.new
        result = adapter.generate("test")
        expect(result).to eq(expected)
      end

      it "skips timeout when set to 0" do
        SemanticCache.configure { |c| c.embedding_timeout = 0 }

        expected = Array.new(1536) { 0.1 }
        stub_embedding_request(embedding: expected)

        adapter = described_class.new
        result = adapter.generate("test")
        expect(result).to eq(expected)
      end
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

      adapter = described_class.new
      result = adapter.generate_batch(["text1", "text2"])

      expect(result.length).to eq(2)
      expect(result[0]).to eq(emb1)
      expect(result[1]).to eq(emb2)
    end

    it "raises ArgumentError for empty array" do
      adapter = described_class.new
      expect { adapter.generate_batch([]) }.to raise_error(ArgumentError, /non-empty Array/)
    end

    it "raises ArgumentError when not an array" do
      adapter = described_class.new
      expect { adapter.generate_batch("hello") }.to raise_error(ArgumentError, /non-empty Array/)
    end

    it "raises ArgumentError when array contains nil" do
      adapter = described_class.new
      expect { adapter.generate_batch(["ok", nil]) }.to raise_error(ArgumentError, /texts\[1\] cannot be nil/)
    end

    it "raises ArgumentError when array contains blank string" do
      adapter = described_class.new
      expect { adapter.generate_batch(["ok", "  "]) }.to raise_error(ArgumentError, /texts\[1\] cannot be blank/)
    end
  end
end
