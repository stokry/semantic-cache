# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Stores::Redis do
  # We mock Redis entirely — no running server needed.
  let(:mock_redis) { instance_double("Redis") }
  let(:store) { described_class.new(redis: mock_redis, namespace: "test") }
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

  describe "#write" do
    it "stores an entry without TTL" do
      entry = make_entry

      expect(mock_redis).to receive(:set).with("test:entry:k1", entry.to_json)
      expect(mock_redis).to receive(:sadd).with("test:keys", "test:entry:k1")

      store.write("k1", entry)
    end

    it "stores an entry with TTL using setex" do
      entry = make_entry(ttl: 3600)

      expect(mock_redis).to receive(:setex).with("test:entry:k1", 3600, entry.to_json)
      expect(mock_redis).to receive(:sadd).with("test:keys", "test:entry:k1")

      store.write("k1", entry)
    end

    it "maintains tag indices" do
      entry = make_entry(tags: [:alpha, :beta])

      allow(mock_redis).to receive(:set)
      allow(mock_redis).to receive(:sadd).with("test:keys", anything)

      expect(mock_redis).to receive(:sadd).with("test:tag:alpha", "test:entry:k1")
      expect(mock_redis).to receive(:sadd).with("test:tag:beta", "test:entry:k1")

      store.write("k1", entry)
    end
  end

  describe "#entries" do
    it "returns empty array when no keys exist" do
      allow(mock_redis).to receive(:smembers).with("test:keys").and_return([])
      expect(store.entries).to eq([])
    end

    it "returns empty array when smembers returns nil" do
      allow(mock_redis).to receive(:smembers).with("test:keys").and_return(nil)
      expect(store.entries).to eq([])
    end

    it "returns non-expired entries" do
      entry = make_entry(query: "hello")
      json = entry.to_json

      allow(mock_redis).to receive(:smembers).with("test:keys").and_return(["test:entry:k1"])
      allow(mock_redis).to receive(:mget).with("test:entry:k1").and_return([json])

      results = store.entries
      expect(results.length).to eq(1)
      expect(results.first.query).to eq("hello")
    end

    it "cleans up keys whose value has expired in Redis" do
      allow(mock_redis).to receive(:smembers).with("test:keys").and_return(["test:entry:k1"])
      allow(mock_redis).to receive(:mget).with("test:entry:k1").and_return([nil])
      expect(mock_redis).to receive(:srem).with("test:keys", "test:entry:k1")

      results = store.entries
      expect(results).to eq([])
    end

    it "removes entries that are expired per TTL logic" do
      entry = make_entry(query: "old", ttl: 0.001)
      # Manually backdate created_at
      entry.instance_variable_set(:@created_at, Time.now.to_f - 10)
      json = entry.to_json

      allow(mock_redis).to receive(:smembers).with("test:keys").and_return(["test:entry:k1"])
      allow(mock_redis).to receive(:mget).with("test:entry:k1").and_return([json])

      # delete_raw will be called
      allow(mock_redis).to receive(:get).with("test:entry:k1").and_return(json)
      allow(mock_redis).to receive(:del)
      allow(mock_redis).to receive(:srem)

      results = store.entries
      expect(results).to eq([])
    end
  end

  describe "#delete" do
    it "deletes the entry and cleans up tags" do
      entry = make_entry(tags: [:alpha])
      json = entry.to_json

      allow(mock_redis).to receive(:get).with("test:entry:k1").and_return(json)
      expect(mock_redis).to receive(:srem).with("test:tag:alpha", "test:entry:k1")
      expect(mock_redis).to receive(:del).with("test:entry:k1")
      expect(mock_redis).to receive(:srem).with("test:keys", "test:entry:k1")

      store.delete("k1")
    end

    it "handles deleting a key that no longer exists" do
      allow(mock_redis).to receive(:get).with("test:entry:k1").and_return(nil)
      expect(mock_redis).to receive(:del).with("test:entry:k1")
      expect(mock_redis).to receive(:srem).with("test:keys", "test:entry:k1")

      store.delete("k1")
    end
  end

  describe "#invalidate_by_tags" do
    it "deletes all entries for the given tags" do
      entry = make_entry(tags: [:products])
      json = entry.to_json

      allow(mock_redis).to receive(:smembers).with("test:tag:products").and_return(["test:entry:k1"])
      allow(mock_redis).to receive(:get).with("test:entry:k1").and_return(json)
      allow(mock_redis).to receive(:del)
      allow(mock_redis).to receive(:srem)

      store.invalidate_by_tags([:products])
    end

    it "handles multiple tags" do
      allow(mock_redis).to receive(:smembers).with("test:tag:a").and_return([])
      allow(mock_redis).to receive(:smembers).with("test:tag:b").and_return([])
      allow(mock_redis).to receive(:del)

      store.invalidate_by_tags([:a, :b])
    end

    it "handles a single tag (not array)" do
      allow(mock_redis).to receive(:smembers).with("test:tag:x").and_return([])
      allow(mock_redis).to receive(:del)

      store.invalidate_by_tags(:x)
    end
  end

  describe "#clear" do
    it "deletes all keys and tag indices" do
      allow(mock_redis).to receive(:smembers).with("test:keys").and_return(["test:entry:k1", "test:entry:k2"])
      allow(mock_redis).to receive(:keys).with("test:tag:*").and_return(["test:tag:a"])

      expect(mock_redis).to receive(:del).with("test:entry:k1")
      expect(mock_redis).to receive(:del).with("test:entry:k2")
      expect(mock_redis).to receive(:del).with("test:keys")
      expect(mock_redis).to receive(:del).with("test:tag:a")

      store.clear
    end

    it "handles empty store" do
      allow(mock_redis).to receive(:smembers).with("test:keys").and_return([])
      allow(mock_redis).to receive(:keys).with("test:tag:*").and_return([])
      expect(mock_redis).to receive(:del).with("test:keys")

      store.clear
    end
  end

  describe "#size" do
    it "returns the number of entries tracked" do
      allow(mock_redis).to receive(:scard).with("test:keys").and_return(5)
      expect(store.size).to eq(5)
    end

    it "converts to integer" do
      allow(mock_redis).to receive(:scard).with("test:keys").and_return("3")
      expect(store.size).to eq(3)
    end
  end

  describe "#write with max_size" do
    let(:store) { described_class.new(redis: mock_redis, namespace: "test", max_size: 2) }

    it "evicts oldest entry when at capacity" do
      old_entry = make_entry(query: "old")
      old_entry.instance_variable_set(:@created_at, Time.now.to_f - 100)

      new_entry = make_entry(query: "new")
      new_entry.instance_variable_set(:@created_at, Time.now.to_f - 10)

      third_entry = make_entry(query: "third")

      # size check returns 2 (at capacity)
      allow(mock_redis).to receive(:scard).with("test:keys").and_return(2)

      # entries call to find oldest
      allow(mock_redis).to receive(:smembers).with("test:keys").and_return(["test:entry:k1", "test:entry:k2"])
      allow(mock_redis).to receive(:mget).with("test:entry:k1", "test:entry:k2").and_return([old_entry.to_json, new_entry.to_json])

      # Eviction of oldest (old_entry) — delete_raw
      allow(mock_redis).to receive(:get).with("test:entry:k1").and_return(old_entry.to_json)
      allow(mock_redis).to receive(:del)
      allow(mock_redis).to receive(:srem)

      # Writing the new entry
      allow(mock_redis).to receive(:set)
      allow(mock_redis).to receive(:sadd)

      store.write("k3", third_entry)
    end
  end

  describe "namespace defaults" do
    it "uses configuration namespace when none provided" do
      SemanticCache.configure { |c| c.namespace = "custom_ns" }

      custom_store = described_class.new(redis: mock_redis)

      allow(mock_redis).to receive(:scard).with("custom_ns:keys").and_return(0)
      expect(custom_store.size).to eq(0)
    end
  end
end
