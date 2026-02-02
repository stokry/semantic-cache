# frozen_string_literal: true

module SemanticCache
  module Adapters
    # Base adapter interface for embedding providers.
    #
    # All adapters must implement:
    #   - #generate(text) => Array<Float>
    #   - #generate_batch(texts) => Array<Array<Float>>
    #
    # Subclasses inherit input validation and timeout handling.
    class Base
      def initialize(model: nil, api_key: nil)
        config = SemanticCache.configuration
        @model = model || config.embedding_model
        @timeout = config.embedding_timeout
      end

      # Generate an embedding vector for the given text.
      # Returns an Array of Floats.
      def generate(text)
        validate_input!(text)
        with_timeout { call_api(text) }
      end

      # Generate embeddings for multiple texts in a single API call.
      # Returns an Array of Arrays of Floats.
      def generate_batch(texts)
        raise ArgumentError, "texts must be a non-empty Array" if !texts.is_a?(Array) || texts.empty?

        texts.each_with_index do |t, i|
          validate_input!(t, label: "texts[#{i}]")
        end

        with_timeout { call_api_batch(texts) }
      end

      protected

      # Subclasses must implement this method.
      # Should return an Array of Floats for the given text.
      def call_api(text)
        raise NotImplementedError, "#{self.class}#call_api must be implemented"
      end

      # Subclasses must implement this method.
      # Should return an Array of Arrays of Floats for the given texts.
      def call_api_batch(texts)
        raise NotImplementedError, "#{self.class}#call_api_batch must be implemented"
      end

      private

      def validate_input!(text, label: "query")
        raise ArgumentError, "#{label} cannot be nil" if text.nil?

        text_str = text.to_s.strip
        raise ArgumentError, "#{label} cannot be blank" if text_str.empty?
      end

      def with_timeout(&block)
        if @timeout && @timeout > 0
          Timeout.timeout(@timeout, Error, "Embedding API request timed out after #{@timeout}s", &block)
        else
          block.call
        end
      end
    end
  end
end
