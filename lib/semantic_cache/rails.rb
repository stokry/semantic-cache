# frozen_string_literal: true

require "semantic_cache"

module SemanticCache
  # Rails integration for SemanticCache.
  #
  # In your Gemfile:
  #   gem "semantic-cache"
  #
  # Then require in an initializer:
  #   require "semantic_cache/rails"
  #
  # Usage in controllers:
  #
  #   class ChatController < ApplicationController
  #     include SemanticCache::Cacheable
  #
  #     cache_ai_calls only: [:create], ttl: 1.hour
  #
  #     def create
  #       response = SemanticCache.current.fetch(params[:message]) do
  #         openai_client.chat(messages: [{ role: "user", content: params[:message] }])
  #       end
  #       render json: { response: response }
  #     end
  #   end
  #
  # Or with per-user namespacing:
  #
  #   class ApplicationController < ActionController::Base
  #     around_action :with_semantic_cache
  #
  #     private
  #
  #     def with_semantic_cache
  #       SemanticCache.with_cache(namespace: "user_#{current_user.id}") do
  #         yield
  #       end
  #     end
  #   end
  #
  module Cacheable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def cache_ai_calls(only: nil, except: nil, ttl: nil, namespace: nil)
        actions = { only: only, except: except }.compact

        around_action(**actions) do |_controller, block|
          SemanticCache.with_cache(namespace: namespace, default_ttl: ttl) do
            block.call
          end
        end
      end
    end
  end

  class << self
    # Thread-local cache instance for use within a request.
    def current
      Thread.current[:semantic_cache_instance]
    end

    # Set a cache instance for the current thread/request scope.
    def with_cache(namespace: nil, **options)
      previous = Thread.current[:semantic_cache_instance]
      Thread.current[:semantic_cache_instance] = Cache.new(namespace: namespace, **options)
      yield
    ensure
      Thread.current[:semantic_cache_instance] = previous
    end
  end
end
