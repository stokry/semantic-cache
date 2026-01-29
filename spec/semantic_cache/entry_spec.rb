# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Entry do
  let(:embedding) { test_embedding }
  let(:entry) do
    described_class.new(
      query: "What is Ruby?",
      embedding: embedding,
      response: "Ruby is a programming language.",
      model: "gpt-4o",
      tags: [:ruby, :languages],
      ttl: 3600,
      metadata: { source: "test" }
    )
  end

  describe "#initialize" do
    it "stores all attributes" do
      expect(entry.query).to eq("What is Ruby?")
      expect(entry.embedding).to eq(embedding)
      expect(entry.response).to eq("Ruby is a programming language.")
      expect(entry.model).to eq("gpt-4o")
      expect(entry.tags).to eq([:ruby, :languages])
      expect(entry.ttl).to eq(3600)
      expect(entry.metadata).to eq({ source: "test" })
    end

    it "sets created_at to current time" do
      expect(entry.created_at).to be_within(1).of(Time.now.to_f)
    end

    it "wraps single tag in array" do
      e = described_class.new(query: "q", embedding: [], response: "r", tags: :single)
      expect(e.tags).to eq([:single])
    end
  end

  describe "#expired?" do
    it "returns false when no TTL is set" do
      e = described_class.new(query: "q", embedding: [], response: "r")
      expect(e.expired?).to be false
    end

    it "returns false when TTL has not elapsed" do
      e = described_class.new(query: "q", embedding: [], response: "r", ttl: 3600)
      expect(e.expired?).to be false
    end

    it "returns true when TTL has elapsed" do
      e = described_class.new(query: "q", embedding: [], response: "r", ttl: 0.001)
      sleep(0.01)
      expect(e.expired?).to be true
    end
  end

  describe "#to_h / #to_json / .from_h / .from_json" do
    it "round-trips through Hash" do
      hash = entry.to_h
      restored = described_class.from_h(hash)

      expect(restored.query).to eq(entry.query)
      expect(restored.response).to eq(entry.response)
      expect(restored.model).to eq(entry.model)
      expect(restored.tags).to eq(entry.tags)
    end

    it "round-trips through JSON" do
      json = entry.to_json
      restored = described_class.from_json(json)

      expect(restored.query).to eq(entry.query)
      expect(restored.response).to eq(entry.response)
    end

    it "handles string keys in from_h" do
      hash = { "query" => "test", "embedding" => [], "response" => "ok" }
      entry = described_class.from_h(hash)
      expect(entry.query).to eq("test")
    end
  end
end
