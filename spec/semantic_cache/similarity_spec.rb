# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Similarity do
  describe ".cosine" do
    it "returns 1.0 for identical vectors" do
      vec = [1.0, 2.0, 3.0]
      expect(described_class.cosine(vec, vec)).to be_within(0.001).of(1.0)
    end

    it "returns -1.0 for opposite vectors" do
      vec_a = [1.0, 2.0, 3.0]
      vec_b = [-1.0, -2.0, -3.0]
      expect(described_class.cosine(vec_a, vec_b)).to be_within(0.001).of(-1.0)
    end

    it "returns 0.0 for orthogonal vectors" do
      vec_a = [1.0, 0.0]
      vec_b = [0.0, 1.0]
      expect(described_class.cosine(vec_a, vec_b)).to be_within(0.001).of(0.0)
    end

    it "returns high similarity for similar vectors" do
      base = test_embedding(1)
      similar = similar_embedding(base, noise: 0.01)
      score = described_class.cosine(base, similar)
      expect(score).to be > 0.95
    end

    it "returns low similarity for different vectors" do
      base = test_embedding(1)
      different = different_embedding(base)
      score = described_class.cosine(base, different)
      expect(score).to be < 0.5
    end

    it "returns 0.0 for empty vectors" do
      expect(described_class.cosine([], [])).to eq(0.0)
    end

    it "raises ArgumentError for vectors of different lengths" do
      expect { described_class.cosine([1.0], [1.0, 2.0]) }.to raise_error(ArgumentError)
    end

    it "handles zero vectors" do
      vec_a = [0.0, 0.0, 0.0]
      vec_b = [1.0, 2.0, 3.0]
      expect(described_class.cosine(vec_a, vec_b)).to eq(0.0)
    end
  end
end
