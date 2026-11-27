# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../script/diagnose_memory"

class MemoryDiagnosticTest < Minitest::Test
  Runner = Petstore::MemoryDiagnostic

  def row(reset)
    { "reset" => reset, "ruby_pid" => 10, "worker_pid" => 20, "ruby_rss_bytes" => 1048576,
      "node" => { "pid" => 20, "has_document" => false, "confirm_armed" => false,
        "handles" => 0, "pending_requests" => 0, "active_fetches" => 0,
        "rss" => 2097152, "heapTotal" => 1048576, "heapUsed" => 524288, "external" => 0, "arrayBuffers" => 0 } }
  end

  def test_requires_complete_reset_sequence_and_single_pid
    assert Runner.validate([row(1), row(2)], 2)
    refute Runner.validate([row(1)], 2)
    refute Runner.validate([row(1), row(1)], 2)
    refute Runner.validate([row(1), row(2).merge("worker_pid" => 21)], 2)
  end

  def test_rejects_uncleared_handles
    bad = row(1)
    bad["node"]["handles"] = 1
    refute Runner.validate([bad], 1)
  end

  def test_summary_uses_mib
    assert_equal 2.0, Runner.summary([row(1)]).fetch("node_rss").fetch(:last_mib)
    assert_equal 0.5, Runner.summary([row(1)]).fetch("node_heapUsed").fetch(:max_mib)
  end
end
