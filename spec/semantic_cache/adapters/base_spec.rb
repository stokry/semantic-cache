# frozen_string_literal: true

require "spec_helper"

RSpec.describe SemanticCache::Adapters::Base do
  before do
    SemanticCache.configure do |c|
      c.openai_api_key = "test-key"
    end
  end

  describe "#generate" do
    it "raises NotImplementedError when call_api is not implemented" do
      adapter = described_class.new
      expect { adapter.generate("test") }.to raise_error(NotImplementedError, /call_api must be implemented/)
    end

    context "input validation" do
      it "raises ArgumentError for nil input" do
        adapter = described_class.new
        expect { adapter.generate(nil) }.to raise_error(ArgumentError, /cannot be nil/)
      end

      it "raises ArgumentError for empty string" do
        adapter = described_class.new
        expect { adapter.generate("") }.to raise_error(ArgumentError, /cannot be blank/)
      end

      it "raises ArgumentError for whitespace-only string" do
        adapter = described_class.new
        expect { adapter.generate("   ") }.to raise_error(ArgumentError, /cannot be blank/)
      end
    end
  end

  describe "#generate_batch" do
    it "raises NotImplementedError when call_api_batch is not implemented" do
      adapter = described_class.new
      expect { adapter.generate_batch(["test"]) }.to raise_error(NotImplementedError, /call_api_batch must be implemented/)
    end

    it "raises ArgumentError for empty array" do
      adapter = described_class.new
      expect { adapter.generate_batch([]) }.to raise_error(ArgumentError, /non-empty Array/)
    end

    it "raises ArgumentError when not an array" do
      adapter = described_class.new
      expect { adapter.generate_batch("hello") }.to raise_error(ArgumentError, /non-empty Array/)
    end

    it "raises ArgumentError when array contains nil" do
      adapter = described_class.new
      expect { adapter.generate_batch(["ok", nil]) }.to raise_error(ArgumentError, /texts\[1\] cannot be nil/)
    end

    it "raises ArgumentError when array contains blank string" do
      adapter = described_class.new
      expect { adapter.generate_batch(["ok", "  "]) }.to raise_error(ArgumentError, /texts\[1\] cannot be blank/)
    end
  end

  describe "timeout" do
    it "respects the configured timeout value" do
      SemanticCache.configure { |c| c.embedding_timeout = 15 }
      adapter = described_class.new
      expect(adapter.instance_variable_get(:@timeout)).to eq(15)
    end

    it "picks up default timeout from config" do
      adapter = described_class.new
      expect(adapter.instance_variable_get(:@timeout)).to eq(30)
    end
  end
end
