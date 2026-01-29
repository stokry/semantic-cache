# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Stats do
  let(:stats) { described_class.new }

  describe "#record_hit" do
    it "increments hit count" do
      stats.record_hit
      expect(stats.hits).to eq(1)
    end

    it "tracks saved cost" do
      stats.record_hit(saved_cost: 0.05)
      stats.record_hit(saved_cost: 0.03)
      expect(stats.total_savings).to be_within(0.001).of(0.08)
    end

    it "sets last_event to :hit" do
      stats.record_hit
      expect(stats.last_event).to eq(:hit)
    end
  end

  describe "#record_miss" do
    it "increments miss count" do
      stats.record_miss
      expect(stats.misses).to eq(1)
    end

    it "sets last_event to :miss" do
      stats.record_miss
      expect(stats.last_event).to eq(:miss)
    end
  end

  describe "#hit_rate" do
    it "returns 0 when no queries" do
      expect(stats.hit_rate).to eq(0.0)
    end

    it "calculates correct hit rate" do
      3.times { stats.record_hit }
      1.times { stats.record_miss }
      expect(stats.hit_rate).to eq(75.0)
    end
  end

  describe "#total_queries" do
    it "returns sum of hits and misses" do
      2.times { stats.record_hit }
      3.times { stats.record_miss }
      expect(stats.total_queries).to eq(5)
    end
  end

  describe "#to_h" do
    it "returns a hash with all stats" do
      stats.record_hit(saved_cost: 0.05)
      stats.record_miss

      h = stats.to_h
      expect(h[:hits]).to eq(1)
      expect(h[:misses]).to eq(1)
      expect(h[:total_queries]).to eq(2)
      expect(h[:hit_rate]).to eq(50.0)
      expect(h[:savings]).to eq("$0.05")
    end
  end

  describe "#report" do
    it "returns a formatted string" do
      stats.record_hit(saved_cost: 1.23)
      report = stats.report
      expect(report).to include("Cache hits: 1")
      expect(report).to include("$1.23")
    end
  end

  describe "#reset!" do
    it "resets all counters" do
      5.times { stats.record_hit(saved_cost: 1.0) }
      3.times { stats.record_miss }
      stats.reset!

      expect(stats.hits).to eq(0)
      expect(stats.misses).to eq(0)
      expect(stats.total_savings).to eq(0.0)
    end
  end
end
