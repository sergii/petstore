# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../script/benchmark_worker_reuse"

class WorkerReuseBenchmarkTest < Minitest::Test
  Runner = Petstore::WorkerReuseBenchmark

  def row(mode, pair, wall, warmup: false)
    { mode: mode, pair: pair, seed: pair + 100, wall_seconds: wall,
      suite_seconds: wall, cpu_seconds: wall, peak_tree_rss_mib: 100,
      warmup: warmup, passed: true }
  end

  def test_alternates_mode_order
    assert_equal %w[fresh persistent], Runner.order(0)
    assert_equal %w[persistent fresh], Runner.order(1)
  end

  def test_paired_statistics_exclude_warmup
    result = Runner.summarize([
      row("fresh", 1, 10, warmup: true), row("persistent", 1, 1, warmup: true),
      row("fresh", 2, 4), row("persistent", 2, 2),
      row("persistent", 3, 3), row("fresh", 3, 3)
    ])
    assert_equal 2, result[:modes]["fresh"][:runs]
    assert_equal 1.5, result[:paired_wall_speedup][:median]
    assert_equal 1.0, result[:paired_wall_seconds_saved][:median]
    assert_equal 1, result[:persistent_wins]
    assert_equal 1, result[:ties]
  end

  def test_rejects_incomplete_or_mismatched_pairs
    assert_raises(RuntimeError) { Runner.summarize([row("fresh", 1, 2)]) }
    wrong_seed = row("persistent", 1, 1).merge(seed: 999)
    assert_raises(RuntimeError) { Runner.summarize([row("fresh", 1, 2), wrong_seed]) }
  end
end
