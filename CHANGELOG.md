# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2025-01-29

### Added

- **Input validation** — `cache.fetch(nil)` and `cache.fetch("")` now raise `ArgumentError` early instead of failing at the API level
- **API timeout** — embedding generation is wrapped in `Timeout.timeout` (default: 30s, configurable via `config.embedding_timeout`)
- **Max cache size** — both Memory and Redis stores support `max_size` with LRU eviction (oldest entry by `created_at` is evicted when full)
- **Redis store tests** — full test coverage for write, entries, delete, tags, clear, size, max_size, and namespace
- **Rails integration tests** — tests for `with_cache`, `current`, `Cacheable` concern, and exception safety
- **Embedding batch validation** — `generate_batch` validates each element in the array

### Improved

- Test coverage increased from 85.6% to 97.67% (113 tests, 0 failures)
- Configuration now includes `embedding_timeout` and `max_cache_size` attributes

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
