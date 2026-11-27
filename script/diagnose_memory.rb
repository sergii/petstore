# frozen_string_literal: true

require_relative "benchmark_system"

module Petstore
  module MemoryDiagnostic
    Base = SystemBenchmark
    NODE_FIELDS = %w[rss heapTotal heapUsed external arrayBuffers].freeze
    module_function

    def validate(rows, expected)
      return false unless rows.size == expected && rows.map { |r| r["reset"] } == (1..expected).to_a
      return false unless rows.map { |r| r["worker_pid"] }.uniq.size == 1 && rows.map { |r| r["ruby_pid"] }.uniq.size == 1
      rows.all? do |row|
        node = row.fetch("node")
        node["pid"] == row["worker_pid"] && node["has_document"] == false &&
          node["confirm_armed"] == false && %w[handles pending_requests active_fetches].all? { |key| node[key] == 0 } &&
          NODE_FIELDS.all? { |key| node[key].is_a?(Numeric) && node[key] >= 0 } &&
          row["ruby_rss_bytes"].is_a?(Integer) && row["ruby_rss_bytes"].positive?
      end
    end

    def summary(rows)
      return {} if rows.empty?
      metrics = NODE_FIELDS.to_h { |key| ["node_#{key}", rows.map { |row| row.fetch("node").fetch(key) }] }
      metrics["ruby_rss"] = rows.map { |row| row.fetch("ruby_rss_bytes") }
      metrics.transform_values do |values|
        { first_mib: values.first / 1048576.0, last_mib: values.last / 1048576.0,
          min_mib: values.min / 1048576.0, max_mib: values.max / 1048576.0 }
      end
    end

    def main(argv)
      options = { suite_repeats: 34, seed: 1081 }
      OptionParser.new do |p|
        p.on("--suite-repeats N", Integer) { |n| options[:suite_repeats] = n }
        p.on("--seed N", Integer) { |n| options[:seed] = n }
      end.parse!(argv)
      abort "Unexpected arguments" unless argv.empty?
      abort "Positive repeats and seed required" unless options.values.all?(&:positive?)
      directory = File.join(Base::ROOT, "tmp", "system-memory", "#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{Process.pid}")
      FileUtils.mkdir_p(directory, mode: 0o700)
      raw = File.join(directory, "memory.jsonl")
      env = Base.child_env("domstride", reuse_worker: true, importmap_cache: false).merge(
        "PETSTORE_SUITE_REPEATS" => options[:suite_repeats].to_s,
        "PETSTORE_MEMORY_FILE" => raw, "NODE_OPTIONS" => nil)
      log_path = File.join(directory, "system.log")
      puts "Memory diagnostic: #{directory}"
      status = nil
      File.open(log_path, "w", 0o600) do |log|
        Open3.popen2e(env, RbConfig.ruby, "-r", File.join(Base::ROOT, "script/domstride_memory_hook.rb"),
          "bin/rails", *Base.test_command(options), "--seed", options[:seed].to_s, chdir: Base::ROOT) do |input, output, wait|
          input.close
          output.each_line { |line| log.write(line); print line }
          status = wait.value
        end
      end
      rows = File.file?(raw) ? File.readlines(raw).map { |line| JSON.parse(line) } : []
      counts = Base.parse_output(File.read(log_path))[:counts]
      expected = { tests: 3 * options[:suite_repeats], assertions: 15 * options[:suite_repeats], failures: 0, errors: 0, skips: 0 }
      passed = status.success? && counts == expected && validate(rows, expected[:tests])
      report = { metadata: Base.metadata(options.merge(reuse_worker: true, importmap_cache: false)),
        counts: counts, expected: expected, passed: passed, samples: rows,
        summary_mib: summary(rows), caveat: "Post-reset natural GC samples; no forced GC. Node RSS excludes esbuild child. Diagnostic timing is not a benchmark." }
      target = File.join(directory, "results.json")
      File.write(target, JSON.pretty_generate(report) + "\n")
      puts "Reset samples: #{rows.size}/#{expected[:tests]}"
      puts JSON.pretty_generate(report[:summary_mib])
      puts "Results: #{target}"
      warn "Memory diagnostic incomplete or parity failed" unless passed
      passed ? 0 : 1
    end
  end
end

exit Petstore::MemoryDiagnostic.main(ARGV) if $PROGRAM_NAME == __FILE__
