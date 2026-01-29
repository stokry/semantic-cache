# frozen_string_literal: true

require_relative "semantic_cache/version"
require_relative "semantic_cache/configuration"
require_relative "semantic_cache/embedding"
require_relative "semantic_cache/similarity"
require_relative "semantic_cache/stores/memory"
require_relative "semantic_cache/stores/redis"
require_relative "semantic_cache/stats"
require_relative "semantic_cache/entry"
require_relative "semantic_cache/cache"
require_relative "semantic_cache/client_wrapper"

module SemanticCache
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class StoreError < Error; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset!
      @configuration = Configuration.new
    end

    # Convenience method to create a new cache instance
    def new(**options)
      Cache.new(**options)
    end
  end
end
