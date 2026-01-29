# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Stores::Memory do
  let(:store) { described_class.new }
  let(:embedding) { test_embedding }

  def make_entry(query: "test", ttl: nil, tags: [])
    SemanticCache::Entry.new(
      query: query,
      embedding: embedding,
      response: "answer",
      tags: tags,
      ttl: ttl
    )
  end

  describe "#write and #entries" do
    it "stores and retrieves entries" do
      store.write("key1", make_entry(query: "q1"))
      expect(store.entries.length).to eq(1)
      expect(store.entries.first.query).to eq("q1")
    end

    it "stores multiple entries" do
      store.write("key1", make_entry(query: "q1"))
      store.write("key2", make_entry(query: "q2"))
      expect(store.entries.length).to eq(2)
    end
  end

  describe "#delete" do
    it "removes the entry" do
      store.write("key1", make_entry)
      store.delete("key1")
      expect(store.size).to eq(0)
    end
  end

  describe "#clear" do
    it "removes all entries" do
      store.write("key1", make_entry)
      store.write("key2", make_entry)
      store.clear
      expect(store.size).to eq(0)
    end
  end

  describe "#size" do
    it "returns the number of entries" do
      expect(store.size).to eq(0)
      store.write("key1", make_entry)
      expect(store.size).to eq(1)
    end
  end

  describe "#invalidate_by_tags" do
    it "removes entries matching any of the given tags" do
      store.write("k1", make_entry(query: "q1", tags: [:a, :b]))
      store.write("k2", make_entry(query: "q2", tags: [:b, :c]))
      store.write("k3", make_entry(query: "q3", tags: [:c, :d]))

      store.invalidate_by_tags([:a])
      expect(store.size).to eq(2)

      store.invalidate_by_tags([:c])
      expect(store.size).to eq(0)
    end
  end

  describe "TTL expiry" do
    it "excludes expired entries" do
      store.write("k1", make_entry(query: "q1", ttl: 0.001))
      store.write("k2", make_entry(query: "q2", ttl: nil))
      sleep(0.02)

      expect(store.entries.length).to eq(1)
      expect(store.entries.first.query).to eq("q2")
    end
  end
end
