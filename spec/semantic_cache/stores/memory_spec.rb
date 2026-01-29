# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Stores::Memory do
  let(:store) { described_class.new }
  let(:embedding) { test_embedding }

  def make_entry(query: "test", ttl: nil, tags: [], created_at: nil)
    entry = SemanticCache::Entry.new(
      query: query,
      embedding: embedding,
      response: "answer",
      tags: tags,
      ttl: ttl
    )
    entry.instance_variable_set(:@created_at, created_at.to_f) if created_at
    entry
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

  describe "max_size eviction" do
    it "evicts oldest entry when at capacity" do
      capped = described_class.new(max_size: 2)

      capped.write("k1", make_entry(query: "oldest", created_at: Time.now - 100))
      capped.write("k2", make_entry(query: "middle", created_at: Time.now - 50))
      capped.write("k3", make_entry(query: "newest"))

      expect(capped.size).to eq(2)
      queries = capped.entries.map(&:query)
      expect(queries).not_to include("oldest")
      expect(queries).to include("middle")
      expect(queries).to include("newest")
    end

    it "does not evict when overwriting same key" do
      capped = described_class.new(max_size: 2)

      capped.write("k1", make_entry(query: "q1"))
      capped.write("k2", make_entry(query: "q2"))
      # Overwrite k1 — should not trigger eviction
      capped.write("k1", make_entry(query: "q1 updated"))

      expect(capped.size).to eq(2)
      queries = capped.entries.map(&:query)
      expect(queries).to include("q1 updated")
      expect(queries).to include("q2")
    end

    it "allows unlimited entries when max_size is nil" do
      unlimited = described_class.new(max_size: nil)

      10.times { |i| unlimited.write("k#{i}", make_entry(query: "q#{i}")) }
      expect(unlimited.size).to eq(10)
    end

    it "works with max_size of 1" do
      tiny = described_class.new(max_size: 1)

      tiny.write("k1", make_entry(query: "first"))
      tiny.write("k2", make_entry(query: "second"))

      expect(tiny.size).to eq(1)
      expect(tiny.entries.first.query).to eq("second")
    end
  end
end
