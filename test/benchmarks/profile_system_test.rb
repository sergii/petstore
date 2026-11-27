# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../script/profile_system"

class ProfileSystemTest < Minitest::Test
  def test_aggregates_multiple_session_profiles
    profile = {
      "rack_requests" => 2, "rack_ms" => 10, "bytes_sent" => 200, "bytes_received" => 300,
      "bundle_hits" => 0, "bundle_misses" => 1,
      "phases_ms" => { "mount.create_window" => 10.5 },
      "commands" => { "mount" => { "count" => 1, "ruby_wall_ms" => 20, "worker_wall_ms" => 15 } }
    }
    result = Petstore::ProfileSystem.aggregate([
      { "kind" => "session", "profile" => profile },
      { "kind" => "session", "profile" => profile },
      { "kind" => "ruby_process", "user_seconds" => 1 }
    ])
    assert_equal 2, result[:sessions]
    assert_equal 4, result[:totals]["rack_requests"]
    assert_equal 40, result[:commands]["mount"]["ruby_wall_ms"]
    assert_equal 30, result[:commands]["mount"]["worker_wall_ms"]
    assert_equal 1, result[:ruby_processes].length
    assert_equal 21.0, result[:phases_ms]["mount.create_window"]
  end
end
