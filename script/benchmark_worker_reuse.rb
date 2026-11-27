# frozen_string_literal: true

require_relative "benchmark_system"

module Petstore
  module WorkerReuseBenchmark
    MODES = %w[fresh persistent].freeze
    METRICS = %i[wall_seconds suite_seconds cpu_seconds peak_tree_rss_mib].freeze
    Base = SystemBenchmark
    module_function

    def order(index, modes = MODES)
      index.even? ? modes : modes.reverse
    end

    def summarize(rows, modes: MODES)
      measured = rows.select { |row| row[:passed] && !row[:warmup] }
      summaries = modes.to_h do |mode|
        samples = measured.select { |row| row[:mode] == mode }
        [mode, { runs: samples.size }.merge(METRICS.to_h { |key| [key, Base.stats(samples.map { |row| row.fetch(key) })] })]
      end
      pairs = measured.group_by { |row| row.fetch(:pair) }.sort.map do |pair, samples|
        fresh = samples.find { |row| row[:mode] == modes.first }
        persistent = samples.find { |row| row[:mode] == modes.last }
        raise "Incomplete pair #{pair}" unless samples.size == 2 && fresh && persistent && fresh[:seed] == persistent[:seed]
        { pair: pair, seed: fresh[:seed],
          wall_seconds_saved: fresh.fetch(:wall_seconds) - persistent.fetch(:wall_seconds),
          wall_speedup: fresh.fetch(:wall_seconds) / persistent.fetch(:wall_seconds) }
      end
      { modes: summaries, pairs: pairs,
        paired_wall_speedup: Base.stats(pairs.map { |row| row[:wall_speedup] }),
        paired_wall_seconds_saved: Base.stats(pairs.map { |row| row[:wall_seconds_saved] }),
        persistent_wins: pairs.count { |row| row[:wall_seconds_saved].positive? },
        ties: pairs.count { |row| row[:wall_seconds_saved].zero? } }
    end

    def main(argv)
      config = Base.options(argv)
      abort "--reuse-worker is not needed: this benchmark controls both modes" if config[:reuse_worker]
      compare_cache = config[:importmap_cache]
      modes = compare_cache ? %w[cache-off cache-on] : MODES
      raise "Benchmark requires macOS or Linux and /usr/bin/time" unless File.executable?("/usr/bin/time") &&
        RbConfig::CONFIG["host_os"].match?(/darwin|linux/)
      directory = File.expand_path(config[:output] || "tmp/system-benchmarks/reuse-ab-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{Process.pid}", Base::ROOT)
      FileUtils.mkdir_p(File.dirname(directory))
      Dir.mkdir(directory, 0o700)
      report = { metadata: Base.metadata(config).merge(experiment: compare_cache ? "paired Importmap cache A/B" : "paired worker reuse A/B",
        modes: modes.to_h { |mode| [mode, { reuse_worker: compare_cache || mode == "persistent", importmap_cache: mode == "cache-on" }] }),
        complete: false, samples: [] }
      Base.write_report(directory, report)
      puts "Benchmark output: #{directory}"
      puts "Warmup: #{config[:warmup]} per mode; measured: #{config[:runs]} per mode"
      begin
        (config[:warmup] + config[:runs]).times do |index|
          warmup = index < config[:warmup]
          seed = config[:seed] + index
          order(index, modes).each do |mode|
            label = format("%02d-%s-%s", index + 1, warmup ? "warmup" : "measured", mode)
            row = Base.run_sample("domstride", seed, File.join(directory, "#{label}.log"),
              config.merge(reuse_worker: compare_cache || mode == "persistent", importmap_cache: mode == "cache-on"))
            row.merge!(mode: mode, reuse_worker: compare_cache || mode == "persistent", importmap_cache: mode == "cache-on", warmup: warmup, pair: index + 1)
            report[:samples] << row
            Base.write_report(directory, report)
            puts format("%-26s %s wall=%s s rss=%s MiB", label, row[:passed] ? "PASS" : "FAIL",
              row[:wall_seconds], row[:peak_tree_rss_mib]&.round(1))
            raise "Invalid sample: #{label}; see #{row[:log]}" unless row[:passed] && row[:wall_seconds].positive?
          end
        end
        report[:summary] = summarize(report[:samples], modes: modes)
        report[:complete] = true
        Base.write_report(directory, report)
        puts "\n#{'Mode'.ljust(12)} #{'Wall median'.rjust(12)} #{'Wall p95'.rjust(10)} #{'CPU median'.rjust(12)} #{'RSS median'.rjust(12)}"
        report[:summary][:modes].each do |mode, row|
          puts format("%-12s %10.3f s %8.3f s %10.3f s %8.1f MiB",
            mode, row[:wall_seconds][:median], row[:wall_seconds][:p95],
            row[:cpu_seconds][:median], row[:peak_tree_rss_mib][:median])
        end
        s = report[:summary]
        puts format("Median paired wall speedup: %.3fx", s[:paired_wall_speedup][:median])
        puts format("Median paired wall seconds saved: %.3f s", s[:paired_wall_seconds_saved][:median])
        puts "#{modes.last} wins: #{s[:persistent_wins]}/#{s[:pairs].size}; ties: #{s[:ties]}"
        0
      rescue StandardError, Interrupt => error
        report[:error] = "#{error.class}: #{error.message}"
        Base.write_report(directory, report)
        warn report[:error]
        warn "Partial results: #{directory}/results.json"
        1
      end
    end
  end
end

exit Petstore::WorkerReuseBenchmark.main(ARGV) if $PROGRAM_NAME == __FILE__
