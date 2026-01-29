# frozen_string_literal: true

require "openai"

module SemanticCache
  class Embedding
    def initialize(model: nil, api_key: nil)
      config = SemanticCache.configuration
      @model = model || config.embedding_model
      @client = OpenAI::Client.new(access_token: api_key || config.openai_api_key)
    end

    # Generate an embedding vector for the given text.
    # Returns an Array of Floats.
    def generate(text)
      response = @client.embeddings(
        parameters: {
          model: @model,
          input: text
        }
      )

      data = response.dig("data", 0, "embedding")
      raise Error, "Failed to generate embedding: #{response}" if data.nil?

      data
    end

    # Generate embeddings for multiple texts in a single API call.
    # Returns an Array of Arrays of Floats.
    def generate_batch(texts)
      response = @client.embeddings(
        parameters: {
          model: @model,
          input: texts
        }
      )

      data = response["data"]
      raise Error, "Failed to generate embeddings: #{response}" if data.nil?

      data.sort_by { |d| d["index"] }.map { |d| d["embedding"] }
    end
  end
end
