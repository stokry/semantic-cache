# frozen_string_literal: true

require "timeout"

module SemanticCache
  module Adapters
    # RubyLLM embedding adapter using the ruby_llm gem.
    #
    # Supports all embedding providers that RubyLLM supports:
    # OpenAI, Gemini, Mistral, Ollama, Bedrock, and more.
    #
    #   # Gemfile
    #   gem "ruby_llm"
    #
    #   SemanticCache.configure do |c|
    #     c.embedding_adapter = :ruby_llm
    #     c.embedding_model = "text-embedding-3-small"
    #   end
    class RubyLLM < Base
      def initialize(model: nil, api_key: nil)
        super

        begin
          require "ruby_llm"
        rescue LoadError
          raise ConfigurationError,
            "The ruby_llm gem is required for the :ruby_llm adapter. " \
            "Add `gem 'ruby_llm'` to your Gemfile."
        end
      end

      protected

      def call_api(text)
        response = ::RubyLLM.embed(text, model: @model)
        vectors = response.vectors

        raise Error, "Failed to generate embedding via RubyLLM" if vectors.nil? || vectors.empty?

        # RubyLLM.embed for single text returns vectors as Array<Array<Float>>
        # We need the first (and only) vector
        vectors.is_a?(Array) && vectors.first.is_a?(Array) ? vectors.first : vectors
      end

      def call_api_batch(texts)
        response = ::RubyLLM.embed(texts, model: @model)
        vectors = response.vectors

        raise Error, "Failed to generate embeddings via RubyLLM" if vectors.nil? || vectors.empty?

        vectors
      end
    end
  end
end
