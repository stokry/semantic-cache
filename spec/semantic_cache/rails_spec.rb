# frozen_string_literal: true

require "spec_helper"
require "semantic_cache/rails"

RSpec.describe "Rails integration" do
  before do
    SemanticCache.configure do |c|
      c.openai_api_key = "test-key"
    end
  end

  describe "SemanticCache.with_cache" do
    it "sets a thread-local cache instance within the block" do
      expect(SemanticCache.current).to be_nil

      SemanticCache.with_cache(namespace: "user_42") do
        expect(SemanticCache.current).to be_a(SemanticCache::Cache)
      end

      expect(SemanticCache.current).to be_nil
    end

    it "restores previous cache instance after the block" do
      previous_cache = SemanticCache::Cache.new
      Thread.current[:semantic_cache_instance] = previous_cache

      SemanticCache.with_cache(namespace: "temp") do
        expect(SemanticCache.current).not_to eq(previous_cache)
      end

      expect(SemanticCache.current).to eq(previous_cache)
    ensure
      Thread.current[:semantic_cache_instance] = nil
    end

    it "restores previous cache even when block raises" do
      Thread.current[:semantic_cache_instance] = nil

      begin
        SemanticCache.with_cache do
          expect(SemanticCache.current).to be_a(SemanticCache::Cache)
          raise "boom"
        end
      rescue RuntimeError
        # expected
      end

      expect(SemanticCache.current).to be_nil
    end

    it "passes options to Cache.new" do
      SemanticCache.with_cache(namespace: "custom", default_ttl: 7200) do
        cache = SemanticCache.current
        expect(cache).to be_a(SemanticCache::Cache)
      end
    end
  end

  describe "SemanticCache.current" do
    it "returns nil when no cache is set" do
      Thread.current[:semantic_cache_instance] = nil
      expect(SemanticCache.current).to be_nil
    end
  end

  describe "SemanticCache::Cacheable" do
    # Minimal controller-like class for testing
    let(:controller_class) do
      klass = Class.new do
        def self.around_action(**_options, &block)
          @around_block = block
        end

        def self.stored_around_block
          @around_block
        end
      end

      klass.include(SemanticCache::Cacheable)
      klass
    end

    it "defines cache_ai_calls class method" do
      expect(controller_class).to respond_to(:cache_ai_calls)
    end

    it "registers an around_action with options" do
      expect(controller_class).to receive(:around_action).with(only: [:create])

      controller_class.cache_ai_calls(only: [:create], ttl: 3600)
    end

    it "compacts nil options" do
      expect(controller_class).to receive(:around_action).with(no_args)

      controller_class.cache_ai_calls
    end
  end
end
