# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Adapters::RubyLLM do
  before do
    SemanticCache.configure do |c|
      c.embedding_adapter = :ruby_llm
    end
  end

  # Mock RubyLLM module for testing without the actual gem
  let(:mock_response) do
    double("RubyLLM::EmbeddingResponse",
      vectors: [Array.new(1536) { 0.1 }],
      model: "text-embedding-3-small"
    )
  end

  let(:mock_batch_response) do
    double("RubyLLM::EmbeddingResponse",
      vectors: [Array.new(1536) { 0.1 }, Array.new(1536) { 0.2 }],
      model: "text-embedding-3-small"
    )
  end

  before do
    # Stub the require so it doesn't fail
    allow_any_instance_of(described_class).to receive(:require).with("ruby_llm").and_return(true)
    # Stub the RubyLLM constant
    stub_const("RubyLLM", double("RubyLLM"))
  end

  describe "#generate" do
    it "returns an embedding vector" do
      allow(::RubyLLM).to receive(:embed).and_return(mock_response)

      adapter = described_class.new
      result = adapter.generate("What is Ruby?")

      expect(result).to eq(Array.new(1536) { 0.1 })
      expect(result.length).to eq(1536)
    end

    it "calls RubyLLM.embed with the correct model" do
      expect(::RubyLLM).to receive(:embed).with("What is Ruby?", model: "text-embedding-3-small").and_return(mock_response)

      adapter = described_class.new
      adapter.generate("What is Ruby?")
    end

    it "uses custom model from configuration" do
      SemanticCache.configure do |c|
        c.embedding_adapter = :ruby_llm
        c.embedding_model = "text-embedding-3-large"
      end

      expect(::RubyLLM).to receive(:embed).with("test", model: "text-embedding-3-large").and_return(mock_response)

      adapter = described_class.new
      adapter.generate("test")
    end

    it "raises on API failure" do
      allow(::RubyLLM).to receive(:embed).and_return(
        double("response", vectors: nil)
      )

      adapter = described_class.new
      expect { adapter.generate("test") }.to raise_error(SemanticCache::Error, /Failed to generate embedding/)
    end

    it "raises on empty vectors" do
      allow(::RubyLLM).to receive(:embed).and_return(
        double("response", vectors: [])
      )

      adapter = described_class.new
      expect { adapter.generate("test") }.to raise_error(SemanticCache::Error, /Failed to generate embedding/)
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
  end

  describe "#generate_batch" do
    it "returns multiple embedding vectors" do
      allow(::RubyLLM).to receive(:embed).and_return(mock_batch_response)

      adapter = described_class.new
      result = adapter.generate_batch(["text1", "text2"])

      expect(result.length).to eq(2)
      expect(result[0]).to eq(Array.new(1536) { 0.1 })
      expect(result[1]).to eq(Array.new(1536) { 0.2 })
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
  end

  describe "LoadError handling" do
    it "raises ConfigurationError when ruby_llm gem is not installed" do
      allow_any_instance_of(described_class).to receive(:require).with("ruby_llm").and_raise(LoadError)

      expect { described_class.new }.to raise_error(
        SemanticCache::ConfigurationError,
        /ruby_llm gem is required/
      )
    end
  end
end
