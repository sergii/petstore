# frozen_string_literal: true

require "json"
require "domstride"

# Loaded only by the diagnostic runner, never by normal system tests.
module PetstoreDomstrideProfile
  module_function

  def write(row)
    File.open(ENV.fetch("PETSTORE_PROFILE_FILE"), "a", 0o600) do |file|
      file.flock(File::LOCK_EX)
      file.puts(JSON.generate(row))
    end
  end

  module SessionClose
    def close
      unless @petstore_profile_captured
        @petstore_profile_captured = true
        PetstoreDomstrideProfile.write(kind: "session", ruby_pid: Process.pid,
                                       worker_pid: worker_pid, profile: profile)
      end
    ensure
      super
    end
  end
end

Domstride::Session.prepend(PetstoreDomstrideProfile::SessionClose)

at_exit do
  cpu = Process.times
  PetstoreDomstrideProfile.write(kind: "ruby_process", pid: Process.pid,
    user_seconds: cpu.utime, system_seconds: cpu.stime,
    waited_child_user_seconds: cpu.cutime, waited_child_system_seconds: cpu.cstime)
end
