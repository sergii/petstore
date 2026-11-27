# frozen_string_literal: true

require_relative "benchmark_system"

module Petstore
  module ProfileSystem
    module_function

    def aggregate(rows)
      sessions = rows.select { |row| row.fetch("kind") == "session" }
      totals = Hash.new(0)
      phases = Hash.new(0.0)
      commands = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      sessions.each do |session|
        profile = session.fetch("profile")
        %w[rack_requests rack_ms bytes_sent bytes_received bundle_hits bundle_misses].each do |key|
          totals[key] += profile.fetch(key)
        end
        %w[importmap_hits importmap_misses].each { |key| totals[key] += profile.fetch(key, 0) }
        profile.fetch("phases_ms", {}).each { |name, ms| phases[name] += ms }
        profile.fetch("commands").each do |name, counters|
          %w[count ruby_wall_ms worker_wall_ms].each do |key|
            commands[name][key] += counters.fetch(key)
          end
        end
      end
      { sessions: sessions.length, totals: totals.to_h,
        phases_ms: phases.sort_by { |_, ms| -ms }.to_h,
        commands: commands.sort_by { |_, counters| -counters["ruby_wall_ms"] }.to_h,
        ruby_processes: rows.select { |row| row.fetch("kind") == "ruby_process" } }
    end

    def main(argv)
      options = { seed: 1081, node_cpu: false, reuse_worker: false, importmap_cache: false }
      OptionParser.new do |parser|
        parser.banner = "Usage: bundle exec ruby script/profile_system.rb [--node-cpu] [--seed N]"
        parser.on("--importmap-cache", "Enable experimental Importmap cache") { options[:importmap_cache] = true }
        parser.on("--reuse-worker", "Enable experimental Domstride worker reuse") { options[:reuse_worker] = true }
        parser.on("--node-cpu", "Capture V8 CPU profiles (may contain local paths)") { options[:node_cpu] = true }
        parser.on("--seed N", Integer) { |n| options[:seed] = n }
      end.parse!(argv)
      abort "Unexpected arguments: #{argv.join(' ')}" unless argv.empty?
      root = SystemBenchmark::ROOT
      directory = File.join(root, "tmp", "system-profiles", "#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{Process.pid}")
      FileUtils.mkdir_p(directory, mode: 0o700)
      File.chmod(0o700, directory)
      raw = File.join(directory, "sessions.jsonl")
      env = SystemBenchmark.child_env("domstride", reuse_worker: options[:reuse_worker], importmap_cache: options[:importmap_cache]).merge(
        "DOMSTRIDE_PROFILE" => "1", "PETSTORE_PROFILE_FILE" => raw, "NODE_OPTIONS" => nil
      )
      if options[:node_cpu]
        support, status = Open3.capture2e({ "NODE_OPTIONS" => nil }, "node", "-p",
          "['--cpu-prof','--cpu-prof-dir'].every(f => process.allowedNodeEnvironmentFlags.has(f))")
        abort "This Node version does not support CPU profiling through NODE_OPTIONS" unless status.success? && support.strip == "true"
        env["NODE_OPTIONS"] = "--cpu-prof --cpu-prof-dir=#{JSON.generate(directory)}"
      end
      puts "Profile output: #{directory}"
      log_path = File.join(directory, "system.log")
      status = nil
      File.open(log_path, "w", 0o600) do |log|
        Open3.popen2e(env, RbConfig.ruby, "-r", File.join(root, "script/domstride_profile_hook.rb"),
                     "bin/rails", "test:system", "--seed", options[:seed].to_s, chdir: root) do |input, output, wait|
          input.close
          output.each_line { |line| log.write(line); print line }
          status = wait.value
        end
      end
      rows = File.file?(raw) ? File.readlines(raw).map { |line| JSON.parse(line) } : []
      result = aggregate(rows)
      counts = SystemBenchmark.parse_output(File.read(log_path))[:counts]
      expected = { tests: 3, assertions: 15, failures: 0, errors: 0, skips: 0 }
      profiles = Dir.glob(File.join(directory, "*.cpuprofile")).map { |path| File.basename(path) }
      passed = status.success? && counts == expected && result[:sessions].positive? &&
        result[:commands].values.any? { |counters| counters["count"].positive? } &&
        !result[:ruby_processes].empty? && (!options[:node_cpu] || !profiles.empty?) &&
        %w[worker.boot_engine mount.assets_total mount.create_window mount.evaluate_modules assets.esbuild_with_rack_and_rewrite].all? { |name| result[:phases_ms].key?(name) }
      report = result.merge(passed: passed, counts: counts, seed: options[:seed],
                            git_commit: SystemBenchmark.capture("git", "rev-parse", "HEAD"),
                            node_cpu_requested: options[:node_cpu], node_cpu_profiles: profiles, reuse_worker: options[:reuse_worker], importmap_cache: options[:importmap_cache],
                            caveat: "Nested wall timers overlap; worker wall is not CPU. Diagnostic instrumentation adds overhead.")
      File.write(File.join(directory, "summary.json"), JSON.pretty_generate(report) + "\n")
      puts "\nSessions captured: #{result[:sessions]}"
      puts "Worker PIDs: #{rows.select { |row| row["kind"] == "session" }.map { |row| row["worker_pid"] }.uniq.join(", ")}"
      puts "\nCommands by Ruby round-trip wall time:"
      result[:commands].each do |name, counters|
        puts format("%-22s %5d calls %9.2f ms round-trip %9.2f ms worker wall",
          name, counters["count"], counters["ruby_wall_ms"], counters["worker_wall_ms"])
      end
      puts JSON.pretty_generate(result[:totals])
      puts "\nMount phases (nested wall times, not additive):"
      result[:phases_ms].each { |name, ms| puts format("%-38s %9.2f ms", name, ms) }
      puts "Summary: #{directory}/summary.json"
      warn "Profile incomplete or test parity failed; inspect system.log" unless passed
      passed ? 0 : 1
    end
  end
end

exit Petstore::ProfileSystem.main(ARGV) if $PROGRAM_NAME == __FILE__
