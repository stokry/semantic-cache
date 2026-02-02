# frozen_string_literal: true

module SemanticCache
  class Embedding
    ADAPTERS = {
      openai: "SemanticCache::Adapters::OpenAI",
      ruby_llm: "SemanticCache::Adapters::RubyLLM"
    }.freeze

    def initialize(model: nil, api_key: nil, adapter: nil)
      config = SemanticCache.configuration
      adapter_name = adapter || config.embedding_adapter

      @adapter = build_adapter(adapter_name, model: model, api_key: api_key)
    end

    # Generate an embedding vector for the given text.
    # Delegates to the configured adapter.
    # Returns an Array of Floats.
    def generate(text)
      @adapter.generate(text)
    end

    # Generate embeddings for multiple texts in a single API call.
    # Delegates to the configured adapter.
    # Returns an Array of Arrays of Floats.
    def generate_batch(texts)
      @adapter.generate_batch(texts)
    end

    private

    def build_adapter(adapter_name, model:, api_key:)
      case adapter_name
      when :openai, "openai"
        Adapters::OpenAI.new(model: model, api_key: api_key)
      when :ruby_llm, "ruby_llm"
        Adapters::RubyLLM.new(model: model, api_key: api_key)
      else
        if adapter_name.respond_to?(:generate) && adapter_name.respond_to?(:generate_batch)
          adapter_name # Duck-typed custom adapter
        else
          raise ConfigurationError,
            "Unknown embedding adapter: #{adapter_name}. " \
            "Use :openai, :ruby_llm, or provide a custom adapter that responds to #generate and #generate_batch."
        end
      end
    end
  end
end
