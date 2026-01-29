# frozen_string_literal: true

require "json"

module SemanticCache
  class Entry
    attr_reader :query, :embedding, :response, :model, :tags, :created_at, :ttl, :metadata

    def initialize(query:, embedding:, response:, model: nil, tags: [], ttl: nil, metadata: {})
      @query = query
      @embedding = embedding
      @response = response
      @model = model
      @tags = Array(tags)
      @created_at = Time.now.to_f
      @ttl = ttl
      @metadata = metadata
    end

    def expired?
      return false if @ttl.nil?

      Time.now.to_f - @created_at > @ttl
    end

    def to_h
      {
        query: @query,
        embedding: @embedding,
        response: @response,
        model: @model,
        tags: @tags,
        created_at: @created_at,
        ttl: @ttl,
        metadata: @metadata
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def self.from_h(hash)
      hash = hash.transform_keys(&:to_sym) if hash.is_a?(Hash)
      entry = new(
        query: hash[:query],
        embedding: hash[:embedding],
        response: hash[:response],
        model: hash[:model],
        tags: hash[:tags] || [],
        ttl: hash[:ttl],
        metadata: hash[:metadata] || {}
      )
      entry.instance_variable_set(:@created_at, hash[:created_at]) if hash[:created_at]
      entry
    end

    def self.from_json(json_string)
      from_h(JSON.parse(json_string))
    end
  end
end
