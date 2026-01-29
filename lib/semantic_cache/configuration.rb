# frozen_string_literal: true

module SemanticCache
  class Configuration
    attr_accessor :similarity_threshold,
                  :embedding_model,
                  :openai_api_key,
                  :default_ttl,
                  :store,
                  :store_options,
                  :track_costs,
                  :model_costs,
                  :namespace

    # Cost per 1K tokens (USD)
    DEFAULT_MODEL_COSTS = {
      # OpenAI
      "gpt-4" => { input: 0.03, output: 0.06 },
      "gpt-4-turbo" => { input: 0.01, output: 0.03 },
      "gpt-4o" => { input: 0.005, output: 0.015 },
      "gpt-4o-mini" => { input: 0.00015, output: 0.0006 },
      "gpt-3.5-turbo" => { input: 0.0005, output: 0.0015 },
      # Anthropic
      "claude-sonnet-4-20250514" => { input: 0.003, output: 0.015 },
      "claude-3-5-haiku-20241022" => { input: 0.001, output: 0.005 },
      # Gemini
      "gemini-pro" => { input: 0.0005, output: 0.0015 },
      "gemini-1.5-pro" => { input: 0.00125, output: 0.005 },
      # Embedding (cost per 1K tokens)
      "text-embedding-3-small" => { input: 0.00002, output: 0.0 },
      "text-embedding-3-large" => { input: 0.00013, output: 0.0 }
    }.freeze

    def initialize
      @similarity_threshold = 0.85
      @embedding_model = "text-embedding-3-small"
      @openai_api_key = ENV["OPENAI_API_KEY"]
      @default_ttl = nil # No expiry by default
      @store = :memory
      @store_options = {}
      @track_costs = true
      @model_costs = DEFAULT_MODEL_COSTS.dup
      @namespace = "semantic_cache"
    end

    def cost_for(model)
      model_costs[model] || { input: 0.001, output: 0.002 }
    end
  end
end
