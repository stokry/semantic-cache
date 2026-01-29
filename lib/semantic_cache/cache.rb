# frozen_string_literal: true

require "digest"

module SemanticCache
  class Cache
    attr_reader :stats

    def initialize(
      similarity_threshold: nil,
      embedding_model: nil,
      store: nil,
      store_options: {},
      default_ttl: nil,
      namespace: nil,
      track_costs: nil
    )
      config = SemanticCache.configuration

      @threshold = similarity_threshold || config.similarity_threshold
      @default_ttl = default_ttl || config.default_ttl
      @track_costs = track_costs.nil? ? config.track_costs : track_costs
      @namespace = namespace || config.namespace

      @embedding = Embedding.new(
        model: embedding_model || config.embedding_model,
        api_key: config.openai_api_key
      )

      @store = build_store(store || config.store, store_options.empty? ? config.store_options : store_options)
      @stats = Stats.new
    end

    # Fetch a cached response or execute the block and cache the result.
    #
    #   cache.fetch("What is Ruby?") do
    #     openai.chat(messages: [{ role: "user", content: "What is Ruby?" }])
    #   end
    #
    # Options:
    #   ttl:   - Time-to-live in seconds (overrides default)
    #   tags:  - Array of tags for grouped invalidation
    #   model: - Model name for cost tracking
    def fetch(query, ttl: nil, tags: [], model: nil, metadata: {}, &block)
      raise ArgumentError, "A block is required" unless block_given?

      start_time = Time.now

      # Generate embedding for the query
      query_embedding = @embedding.generate(query)

      # Search for a semantically similar cached entry
      match = find_similar(query_embedding)

      if match
        elapsed = ((Time.now - start_time) * 1000).round(2)
        saved_cost = estimate_cost(model)
        @stats.record_hit(saved_cost: saved_cost, response_time: elapsed)
        return match.response
      end

      # Cache miss — execute the block
      response = block.call

      elapsed = ((Time.now - start_time) * 1000).round(2)
      @stats.record_miss(response_time: elapsed)

      # Store the new entry
      entry = Entry.new(
        query: query,
        embedding: query_embedding,
        response: response,
        model: model,
        tags: Array(tags),
        ttl: ttl || @default_ttl,
        metadata: metadata
      )

      key = generate_key(query)
      @store.write(key, entry)

      response
    end

    # Convenience methods for specific providers

    def fetch_openai(query, model: "gpt-4o", **options, &block)
      fetch(query, model: model, **options, &block)
    end

    def fetch_anthropic(query, model: "claude-sonnet-4-20250514", **options, &block)
      fetch(query, model: model, **options, &block)
    end

    def fetch_gemini(query, model: "gemini-pro", **options, &block)
      fetch(query, model: model, **options, &block)
    end

    # Invalidate cached entries by tags.
    #
    #   cache.invalidate(tags: [:product_info])
    #   cache.invalidate(tags: "user_data")
    def invalidate(tags:)
      @store.invalidate_by_tags(Array(tags))
    end

    # Clear all cached entries.
    def clear
      @store.clear
      @stats.reset!
    end

    # Return current cache statistics as a Hash.
    def current_stats
      @stats.to_h
    end

    # Return a formatted stats report string.
    def detailed_stats
      @stats.report
    end

    # Savings report string.
    def savings_report
      s = @stats
      "Total saved: #{format("$%.2f", s.total_savings)} (#{s.hits} cached calls)"
    end

    # Number of entries currently in the cache.
    def size
      @store.size
    end

    private

    def find_similar(query_embedding)
      entries = @store.entries
      return nil if entries.empty?

      best_match = nil
      best_score = -1.0

      entries.each do |entry|
        next if entry.expired?

        score = Similarity.cosine(query_embedding, entry.embedding)
        if score > best_score
          best_score = score
          best_match = entry
        end
      end

      return nil if best_match.nil? || best_score < @threshold

      best_match
    end

    def estimate_cost(model)
      return 0.0 unless @track_costs && model

      costs = SemanticCache.configuration.cost_for(model)
      # Rough estimate: average request ~500 input tokens, ~200 output tokens
      ((costs[:input] * 0.5) + (costs[:output] * 0.2)).round(6)
    end

    def generate_key(query)
      Digest::SHA256.hexdigest("#{@namespace}:#{query}")[0, 16]
    end

    def build_store(type, options)
      case type
      when :memory, "memory"
        Stores::Memory.new(**options)
      when :redis, "redis"
        Stores::Redis.new(**options)
      when Stores::Memory, Stores::Redis
        type # Already instantiated
      else
        if type.respond_to?(:write) && type.respond_to?(:entries)
          type # Duck-typed custom store
        else
          raise ConfigurationError, "Unknown store type: #{type}. Use :memory or :redis."
        end
      end
    end
  end
end
