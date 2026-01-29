# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2025-01-29

### Added

- Core semantic caching with cosine similarity matching
- In-memory and Redis cache stores
- Embedding generation via OpenAI `text-embedding-3-small`
- Configurable similarity threshold (default: 0.85)
- TTL-based and tag-based cache invalidation
- Cost tracking and savings reports
- Multi-model support (OpenAI, Anthropic, Gemini)
- Client wrapper / middleware pattern
- Rails integration (concern + around_action helper)
- Thread-safe statistics tracking
- Comprehensive test suite
