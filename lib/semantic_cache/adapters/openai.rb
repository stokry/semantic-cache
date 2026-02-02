# frozen_string_literal: true

require "openai"
require "timeout"

module SemanticCache
  module Adapters
    # OpenAI embedding adapter using the ruby-openai gem.
    #
    # This is the default adapter and requires the `ruby-openai` gem.
    #
    #   SemanticCache.configure do |c|
    #     c.embedding_adapter = :openai
    #     c.openai_api_key = "sk-..."
    #   end
    class OpenAI < Base
      def initialize(model: nil, api_key: nil)
        super
        config = SemanticCache.configuration
        @client = ::OpenAI::Client.new(access_token: api_key || config.openai_api_key)
      end

      protected

      def call_api(text)
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

      def call_api_batch(texts)
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
end
