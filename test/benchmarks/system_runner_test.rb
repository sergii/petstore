# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../script/benchmark_system"

class SystemBenchmarkRunnerTest < Minitest::Test
  Runner = Petstore::SystemBenchmark

  def test_statistics_use_nearest_rank_and_even_median
    result = Runner.stats((1..10).to_a.reverse)
    assert_equal 5.5, result[:median]
    assert_equal 10, result[:p95]
    assert_equal 5.5, result[:mean]
    assert_nil Runner.stats([])
  end

  def test_alternates_order
    assert_equal %w[selenium domstride], Runner.driver_order(0)
    assert_equal %w[domstride selenium], Runner.driver_order(1)
  end

  def test_parse_rails_and_external_time
    result = Runner.parse_output(<<~LOG)
      Finished in 2.919743s, 1.0275 runs/s
      3 runs, 15 assertions, 0 failures, 0 errors, 0 skips
      real 3.42
      user 1.25
      sys 0.25
    LOG
    assert_equal({ tests: 3, assertions: 15, failures: 0, errors: 0, skips: 0 }, result[:counts])
    assert_equal 3.42, result[:wall_seconds]
    assert_equal 2.919743, result[:suite_seconds]
    assert_equal 1.5, result[:cpu_seconds]
    assert_nil Runner.parse_output("crash")[:counts]
  end

  def test_tree_counts_group_and_transitive_descendants_once
    rows = [[12, 11, 12, 100], [13, 12, 12, 200], [14, 13, 14, 300],
            [15, 1, 12, 400], [99, 1, 99, 900]]
    assert_equal 1000, Runner.tree_rss_kib(rows.reverse, 12)
  end

  def test_options_and_environment
    assert_equal 10, Runner.options([])[:runs]
    assert_raises(ArgumentError) { Runner.options(%w[--runs 0]) }
    env = Runner.child_env("domstride")
    assert_equal "jsdom31", env["DOMSTRIDE_ENGINE"]
    assert_equal "bundle", env["DOMSTRIDE_ASSETS"]
    assert_nil env["DOMSTRIDE_RECORD_DIR"]
    assert_equal "1", env["PARALLEL_WORKERS"]
    assert_equal "0", env["DOMSTRIDE_REUSE_WORKER"]
    assert_equal "1", Runner.child_env("domstride", reuse_worker: true)["DOMSTRIDE_REUSE_WORKER"]
    assert_equal "0", Runner.child_env("selenium", reuse_worker: true)["DOMSTRIDE_REUSE_WORKER"]
    assert Runner.options(%w[--reuse-worker])[:reuse_worker]
  end
end
