# frozen_string_literal: true

require "json"

module SemanticCache
  module Stores
    # Redis-backed cache store.
    # Suitable for production, multi-process, and distributed apps.
    #
    # Requires the `redis` gem: gem install redis
    #
    # Options:
    #   max_size: Maximum number of entries to keep. When exceeded, the oldest
    #             entry (by created_at) is evicted. nil = unlimited.
    class Redis
      def initialize(redis: nil, namespace: nil, max_size: nil, **options)
        @namespace = namespace || SemanticCache.configuration.namespace
        @redis = redis || connect(options)
        @max_size = max_size
      end

      # Store a cache entry. Evicts the oldest entry if max_size is reached.
      def write(key, entry)
        evict_oldest! if @max_size && size >= @max_size

        full_key = namespaced_key(key)
        data = entry.to_json

        if entry.ttl
          @redis.setex(full_key, entry.ttl.to_i, data)
        else
          @redis.set(full_key, data)
        end

        # Maintain tag index
        entry.tags.each do |tag|
          @redis.sadd(tag_key(tag), full_key)
        end

        # Add to the set of all keys for scanning
        @redis.sadd(keys_set_key, full_key)
      end

      # Retrieve all non-expired entries.
      # Returns an Array of Entry objects.
      def entries
        keys = @redis.smembers(keys_set_key)
        return [] if keys.nil? || keys.empty?

        values = @redis.mget(*keys)
        result = []

        keys.each_with_index do |key, i|
          if values[i].nil?
            # Key expired in Redis; remove from set
            @redis.srem(keys_set_key, key)
            next
          end

          entry = Entry.from_json(values[i])
          if entry.expired?
            delete_raw(key)
            next
          end

          result << entry
        end

        result
      end

      # Delete a specific entry by key.
      def delete(key)
        delete_raw(namespaced_key(key))
      end

      # Delete all entries matching the given tags.
      def invalidate_by_tags(tags)
        Array(tags).each do |tag|
          keys = @redis.smembers(tag_key(tag))
          keys&.each { |key| delete_raw(key) }
          @redis.del(tag_key(tag))
        end
      end

      # Delete all entries.
      def clear
        keys = @redis.smembers(keys_set_key)
        keys&.each { |key| @redis.del(key) }
        @redis.del(keys_set_key)

        # Clean up tag indices
        tag_keys = @redis.keys("#{@namespace}:tag:*")
        tag_keys.each { |key| @redis.del(key) }
      end

      # Number of entries in the store.
      def size
        @redis.scard(keys_set_key).to_i
      end

      private

      def connect(options)
        require "redis"
        ::Redis.new(**options)
      end

      def namespaced_key(key)
        "#{@namespace}:entry:#{key}"
      end

      def tag_key(tag)
        "#{@namespace}:tag:#{tag}"
      end

      def keys_set_key
        "#{@namespace}:keys"
      end

      def delete_raw(full_key)
        data = @redis.get(full_key)
        if data
          entry = Entry.from_json(data)
          entry.tags.each do |tag|
            @redis.srem(tag_key(tag), full_key)
          end
        end
        @redis.del(full_key)
        @redis.srem(keys_set_key, full_key)
      end

      # Evict the oldest entry (by created_at) to make room for a new one.
      def evict_oldest!
        all_entries = entries
        return if all_entries.empty?

        oldest = all_entries.min_by(&:created_at)
        key = @redis.smembers(keys_set_key).find do |k|
          data = @redis.get(k)
          next false unless data

          Entry.from_json(data).query == oldest.query
        end
        delete_raw(key) if key
      end
    end
  end
end
