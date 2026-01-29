# frozen_string_literal: true

module SemanticCache
  # Wraps an OpenAI client (or compatible) to automatically cache chat calls.
  #
  #   client = OpenAI::Client.new
  #   cached = SemanticCache::ClientWrapper.new(client)
  #
  #   # All chat calls are automatically cached
  #   cached.chat(parameters: { model: "gpt-4o", messages: [...] })
  #
  # Or use the shorthand:
  #
  #   cached = SemanticCache.wrap(client)
  #
  class ClientWrapper
    def initialize(client, cache: nil, **cache_options)
      @client = client
      @cache = cache || Cache.new(**cache_options)
    end

    def chat(parameters: {}, **kwargs)
      messages = parameters[:messages] || parameters["messages"] || []
      model = parameters[:model] || parameters["model"]

      # Use the last user message as the cache key
      user_message = messages.reverse.find { |m| m[:role] == "user" || m["role"] == "user" }
      query = user_message && (user_message[:content] || user_message["content"])

      if query
        @cache.fetch(query, model: model) do
          @client.chat(parameters: parameters, **kwargs)
        end
      else
        @client.chat(parameters: parameters, **kwargs)
      end
    end

    # Delegate everything else to the wrapped client
    def method_missing(method, ...)
      if @client.respond_to?(method)
        @client.send(method, ...)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @client.respond_to?(method, include_private) || super
    end

    # Access the underlying cache for stats, invalidation, etc.
    def semantic_cache
      @cache
    end
  end

  class << self
    # Convenience: wrap a client with semantic caching.
    #
    #   cached_client = SemanticCache.wrap(openai_client)
    def wrap(client, **options)
      ClientWrapper.new(client, **options)
    end
  end
end
