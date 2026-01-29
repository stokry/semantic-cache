# frozen_string_literal: true

require "openai"
require "timeout"

module SemanticCache
  class Embedding
    def initialize(model: nil, api_key: nil)
      config = SemanticCache.configuration
      @model = model || config.embedding_model
      @timeout = config.embedding_timeout
      @client = OpenAI::Client.new(access_token: api_key || config.openai_api_key)
    end

    # Generate an embedding vector for the given text.
    # Returns an Array of Floats.
    #
    # Raises ArgumentError if text is nil or empty.
    # Raises SemanticCache::Error on API failure or timeout.
    def generate(text)
      validate_input!(text)

      response = with_timeout do
        @client.embeddings(
          parameters: {
            model: @model,
            input: text
          }
        )
      end

      data = response.dig("data", 0, "embedding")
      raise Error, "Failed to generate embedding: #{response}" if data.nil?

      data
    end

    # Generate embeddings for multiple texts in a single API call.
    # Returns an Array of Arrays of Floats.
    #
    # Raises ArgumentError if texts is empty or contains nil/blank entries.
    # Raises SemanticCache::Error on API failure or timeout.
    def generate_batch(texts)
      raise ArgumentError, "texts must be a non-empty Array" if !texts.is_a?(Array) || texts.empty?

      texts.each_with_index do |t, i|
        validate_input!(t, label: "texts[#{i}]")
      end

      response = with_timeout do
        @client.embeddings(
          parameters: {
            model: @model,
            input: texts
          }
        )
      end

      data = response["data"]
      raise Error, "Failed to generate embeddings: #{response}" if data.nil?

      data.sort_by { |d| d["index"] }.map { |d| d["embedding"] }
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
