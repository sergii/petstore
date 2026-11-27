#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "etc"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "rbconfig"
require "time"

module Petstore
  module SystemBenchmark
    DRIVERS = %w[selenium domstride].freeze
    ROOT = File.expand_path("..", __dir__)
    DEFAULTS = { runs: 10, warmup: 2, seed: 1081, sample_ms: 100,
                 timeout: 180, expected_tests: 3, expected_assertions: 15 }.freeze
    SUMMARY = /(\d+)\s+runs?,\s+(\d+)\s+assertions?,\s+(\d+)\s+failures?,\s+(\d+)\s+errors?,\s+(\d+)\s+skips?/
    DOMSTRIDE_ENV = {
      "DOMSTRIDE_RUNTIME" => "node",
      "DOMSTRIDE_ENGINE" => "jsdom31",
      "DOMSTRIDE_PERFORMANCE_PROFILE" => "compatible",
      "DOMSTRIDE_ASSETS" => "bundle",
      "DOMSTRIDE_ASSET_WARNINGS" => "strict",
      "DOMSTRIDE_CLOCK" => "real",
      "DOMSTRIDE_SETTLING" => "checkpoint",
      "DOMSTRIDE_WAIT" => "poll",
      "DOMSTRIDE_BUNDLE_CACHE" => "off",
      "DOMSTRIDE_QUERY_PREFETCH" => "0",
      "DOMSTRIDE_PROFILE" => "0",
      "DOMSTRIDE_MEDIA_PROFILE" => "off",
      "DOMSTRIDE_WEBSOCKET_URL" => nil,
      "DOMSTRIDE_RECORD_DIR" => nil,
      "DOMSTRIDE_RECORD_HTML" => nil,
      "DOMSTRIDE_FAILURE_DIR" => nil,
      "DOMSTRIDE_FAILURE_HTML" => nil
    }.freeze
    SELENIUM_ENV = {
      "SE_TIMEOUT" => "900",
      "SE_SKIP_DRIVER_IN_PATH" => "true",
      "SE_FORCE_BROWSER_DOWNLOAD" => "true",
      "SE_BROWSER_VERSION" => "157.0.8103.78",
      "SE_BROWSER_PATH" => nil,
      "SE_DRIVER_PATH" => nil
    }.freeze

    module_function

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def options(argv)
      config = DEFAULTS.dup
      parser = OptionParser.new do |p|
        p.banner = "Usage: bundle exec ruby script/benchmark_system.rb [options]"
        p.on("--runs N", Integer, "Measured runs per driver (10)") { |n| config[:runs] = n }
        p.on("--warmup N", Integer, "Warmup runs per driver (2)") { |n| config[:warmup] = n }
        p.on("--seed N", Integer, "Starting seed (1081)") { |n| config[:seed] = n }
        p.on("--sample-ms N", Integer, "Process-tree RSS sampling interval (100 ms)") { |n| config[:sample_ms] = n }
        p.on("--timeout N", Integer, "Maximum seconds per invocation (180)") { |n| config[:timeout] = n }
        p.on("--expected-tests N", Integer, "Required passing test count (3)") { |n| config[:expected_tests] = n }
        p.on("--expected-assertions N", Integer, "Required assertion count (15)") { |n| config[:expected_assertions] = n }
        p.on("--output DIR", "New output directory under tmp by default") { |v| config[:output] = v }
      end
      parser.parse!(argv)
      raise ArgumentError, "Unexpected arguments: #{argv.join(' ')}" unless argv.empty?
      %i[runs seed timeout expected_tests expected_assertions].each do |key|
        raise ArgumentError, "#{key} must be positive" unless config.fetch(key).positive?
      end
      raise ArgumentError, "warmup must be nonnegative" if config[:warmup].negative?
      raise ArgumentError, "sample-ms must be at least 25" if config[:sample_ms] < 25
      config
    end

    def driver_order(index)
      index.even? ? DRIVERS : DRIVERS.reverse
    end

    def median(values)
      sorted = values.sort
      middle = sorted.length / 2
      sorted.length.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
    end

    def stats(values)
      values = values.compact.sort
      return nil if values.empty?
      {
        samples: values.length,
        min: values.first,
        median: median(values),
        mean: values.sum.fdiv(values.length),
        p95: values[(values.length * 0.95).ceil - 1],
        max: values.last
      }
    end

    def parse_output(output)
      match = output.scan(SUMMARY).last
      counts = match && %i[tests assertions failures errors skips].zip(match.map(&:to_i)).to_h
      timings = {}
      %w[real user sys].each do |key|
        raw = output.scan(/^#{key}\s+(\d+(?:\.\d+)?)\s*$/).last
        timings[key] = raw.first.to_f if raw
      end
      suite = output.scan(/Finished in (\d+(?:\.\d+)?)s/).last
      { counts: counts, wall_seconds: timings["real"],
        suite_seconds: suite && suite.first.to_f,
        cpu_user_seconds: timings["user"], cpu_system_seconds: timings["sys"],
        cpu_seconds: timings.values_at("user", "sys").all? ? timings["user"] + timings["sys"] : nil }
    end

    # Include process-group members and descendants, without counting a PID twice.
    # RSS is a sampled sum, not unique memory or an exact kernel peak.
    def tree_rss_kib(rows, root)
      members = { root => true }
      rows.each { |pid, _, pgid, _| members[pid] = true if pgid == root }
      loop do
        before = members.size
        rows.each { |pid, ppid, _, _| members[pid] = true if members[ppid] }
        break if members.size == before
      end
      rows.sum { |pid, _, _, rss| members[pid] ? rss : 0 }
    end

    def sample_rss(root)
      output, status = Open3.capture2({ "LC_ALL" => "C" }, "ps", "-ax", "-o", "pid=", "-o", "ppid=", "-o", "pgid=", "-o", "rss=")
      raise "ps failed" unless status.success?
      rows = output.lines.filter_map do |line|
        values = line.split
        values.map(&:to_i) if values.length == 4 && values.all? { |v| v.match?(/\A\d+\z/) }
      end
      tree_rss_kib(rows, root)
    end

    def child_env(driver)
      # Ignore ambient driver tuning while retaining the configured runtime/cache locations.
      ENV.keys.grep(/\A(?:DOMSTRIDE_|SE_)/).to_h { |key| [key, nil] }
        .merge(ENV.to_h.slice("DOMSTRIDE_RUNTIME_HOME", "SE_CACHE_PATH"))
        .merge(DOMSTRIDE_ENV, SELENIUM_ENV)
        .merge("SYSTEM_TEST_DRIVER" => driver, "RAILS_ENV" => "test",
               "PARALLEL_WORKERS" => "1", "LC_ALL" => "C")
    end

    def kill_group(pid)
      Process.kill("KILL", -pid)
    rescue Errno::ESRCH
      nil
    end

    def run_sample(driver, seed, path, config)
      pid = nil
      status = nil
      peak = nil
      samples = 0
      timed_out = false
      start = monotonic
      File.open(path, "w", 0o600) do |log|
        pid = Process.spawn(child_env(driver), "/usr/bin/time", "-p", RbConfig.ruby,
                            "bin/rails", "test:system", "--seed", seed.to_s,
                            chdir: ROOT, out: log, err: log, pgroup: true)
        begin
          loop do
            rss = sample_rss(pid)
            peak = [peak || 0, rss].max
            samples += 1 if rss.positive?
            result = Process.waitpid2(pid, Process::WNOHANG)
            if result
              status = result.last
              break
            end
            if monotonic - start >= config[:timeout]
              timed_out = true
              kill_group(pid)
              status = Process.waitpid2(pid).last
              break
            end
            sleep config[:sample_ms] / 1000.0
          end
        ensure
          unless status
            kill_group(pid)
            begin
              Process.waitpid(pid)
            rescue Errno::ECHILD
              nil
            end
          end
        end
      end
      result = parse_output(File.read(path))
      counts = result[:counts]
      expected = { tests: config[:expected_tests], assertions: config[:expected_assertions], failures: 0, errors: 0, skips: 0 }
      passed = !timed_out && status.success? && counts == expected &&
        %i[wall_seconds suite_seconds cpu_seconds].all? { |key| !result[key].nil? } && samples.positive?
      result.merge(driver: driver, seed: seed, log: File.basename(path),
                   exit_code: status.exitstatus, exit_signal: status.termsig,
                   timed_out: timed_out, passed: passed, rss_samples: samples,
                   peak_tree_rss_mib: samples.positive? ? peak / 1024.0 : nil)
    end

    def capture(*command)
      output, status = Open3.capture2e(*command, chdir: ROOT)
      status.success? ? output.strip : nil
    rescue Errno::ENOENT
      nil
    end

    def metadata(config)
      lock = File.join(ROOT, "Gemfile.lock")
      { timestamp_utc: Time.now.utc.iso8601, ruby: RUBY_DESCRIPTION,
        node: capture("node", "--version"), platform: RbConfig::CONFIG["host_os"],
        architecture: RbConfig::CONFIG["host_cpu"], logical_cpus: Etc.nprocessors,
        git_commit: capture("git", "rev-parse", "HEAD"),
        tracked_worktree_status: capture("git", "status", "--porcelain", "--untracked-files=no"),
        lock_sha256: Digest::SHA256.file(lock).hexdigest,
        domstride_revision: File.read(lock)[/^\s*revision: ([a-f0-9]{40})$/, 1],
        driver_config: { selenium: SELENIUM_ENV, domstride: DOMSTRIDE_ENV },
        config: config, p95_method: "nearest rank",
        cpu_method: "/usr/bin/time -p user + sys (waited child accounting; detached work may be excluded)",
        rss_method: "sampled concurrent sum of process-group and descendant RSS; shared pages may be counted repeatedly",
        timing_scope: "fresh Rails test process per sample, including startup; setup outside measured runs" }
    end

    def summarize(samples)
      DRIVERS.to_h do |driver|
        rows = samples.select { |row| row[:driver] == driver && !row[:warmup] && row[:passed] }
        metrics = %i[wall_seconds suite_seconds cpu_seconds peak_tree_rss_mib]
        [driver, { runs: rows.length }.merge(metrics.to_h { |key| [key, stats(rows.map { |r| r[key] })] })]
      end
    end

    def write_report(directory, report)
      target = File.join(directory, "results.json")
      temporary = "#{target}.tmp"
      File.write(temporary, JSON.pretty_generate(report) + "\n")
      File.rename(temporary, target)
    end

    def print_summary(report)
      summary = report.fetch(:summary)
      puts "\n#{'Driver'.ljust(12)} #{'Wall median'.rjust(12)} #{'Wall p95'.rjust(10)} #{'CPU median'.rjust(12)} #{'RSS median'.rjust(12)}"
      DRIVERS.each do |driver|
        row = summary.fetch(driver)
        next if row[:runs].zero?
        puts format("%-12s %10.3f s %8.3f s %10.3f s %8.1f MiB",
                    driver, row[:wall_seconds][:median], row[:wall_seconds][:p95],
                    row[:cpu_seconds][:median], row[:peak_tree_rss_mib][:median])
      end
      speedup = report[:wall_median_speedup]
      puts format("Selenium / Domstride wall median: %.3fx", speedup) if speedup
    end

    def main(argv)
      config = options(argv)
      raise "Benchmark requires macOS or Linux and /usr/bin/time" unless File.executable?("/usr/bin/time") &&
        RbConfig::CONFIG["host_os"].match?(/darwin|linux/)
      directory = File.expand_path(config[:output] || "tmp/system-benchmarks/#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{Process.pid}", ROOT)
      FileUtils.mkdir_p(File.dirname(directory))
      Dir.mkdir(directory, 0o700)
      report = { metadata: metadata(config), complete: false, samples: [] }
      write_report(directory, report)
      puts "Benchmark output: #{directory}"
      puts "Warmup: #{config[:warmup]} per driver; measured: #{config[:runs]} per driver"
      begin
        (config[:warmup] + config[:runs]).times do |index|
          warmup = index < config[:warmup]
          seed = config[:seed] + index
          driver_order(index).each do |driver|
            label = format("%02d-%s-%s", index + 1, warmup ? "warmup" : "measured", driver)
            row = run_sample(driver, seed, File.join(directory, "#{label}.log"), config)
            row.merge!(warmup: warmup, pair: index + 1)
            report[:samples] << row
            write_report(directory, report)
            puts format("%-26s %s wall=%s s rss=%s MiB", label, row[:passed] ? "PASS" : "FAIL",
                        row[:wall_seconds], row[:peak_tree_rss_mib]&.round(1))
            raise "Invalid sample: #{label}; see #{row[:log]}" unless row[:passed]
          end
        end
        report[:summary] = summarize(report[:samples])
        selenium = report[:summary]["selenium"][:wall_seconds][:median]
        domstride = report[:summary]["domstride"][:wall_seconds][:median]
        report[:wall_median_speedup] = selenium / domstride if domstride.positive?
        report[:complete] = true
        write_report(directory, report)
        print_summary(report)
        0
      rescue StandardError, Interrupt => error
        report[:error] = "#{error.class}: #{error.message}"
        write_report(directory, report)
        warn report[:error]
        warn "Partial results: #{directory}/results.json"
        1
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  exit Petstore::SystemBenchmark.main(ARGV)
end
