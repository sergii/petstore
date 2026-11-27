# frozen_string_literal: true

require_relative "benchmark_system"

module Petstore
  module ParallelBenchmark
    Base = SystemBenchmark
    module_function

    def main(argv)
      options = { workers: [1, 2, 4], driver: "domstride", runs: 2, warmup: 1, suite_repeats: 34, timeout: 600 }
      OptionParser.new do |p|
        p.on("--workers LIST", "Comma-separated worker counts") { |v| options[:workers] = v.split(",").map { |n| Integer(n) } }
        p.on("--driver NAME", Base::DRIVERS) { |v| options[:driver] = v }
        p.on("--runs N", Integer) { |v| options[:runs] = v }
        p.on("--warmup N", Integer) { |v| options[:warmup] = v }
        p.on("--suite-repeats N", Integer) { |v| options[:suite_repeats] = v }
        p.on("--timeout N", Integer) { |v| options[:timeout] = v }
      end.parse!(argv)
      abort "Unexpected arguments" unless argv.empty?
      workers = options[:workers]
      abort "Worker list must start at 1, be unique and increasing, and contain only positive integers" unless workers.first == 1 && workers == workers.uniq.sort && workers.all?(&:positive?)
      abort "Requires at least two repeats and enough tests for every worker" unless options[:suite_repeats] >= 2 && workers.last <= 3 * options[:suite_repeats]
      config = Base.options(["--runs", options[:runs].to_s, "--warmup", options[:warmup].to_s,
        "--suite-repeats", options[:suite_repeats].to_s, "--timeout", options[:timeout].to_s, "--reuse-worker"])
      config[:reuse_worker] = options[:driver] == "domstride"
      config[:audit_workers] = true
      directory = File.join(Base::ROOT, "tmp/system-parallel", "#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{Process.pid}")
      FileUtils.mkdir_p(directory, mode: 0o700)
      report = { metadata: Base.metadata(config.merge(worker_counts: workers, driver: options[:driver])),
        complete: false, samples: [] }
      Base.write_report(directory, report)
      puts "Parallel benchmark: #{directory}"
      puts "Driver: #{options[:driver]}; workers: #{workers.join(', ')}; tests: #{config[:expected_tests]}"
      begin
        (config[:warmup] + config[:runs]).times do |index|
          order = index.even? ? workers : workers.reverse
          order.each do |count|
            warmup = index < config[:warmup]
            label = format("%02d-%s-%02d-workers", index + 1, warmup ? "warmup" : "measured", count)
            sample = Base.run_sample(options[:driver], config[:seed] + index, File.join(directory, "#{label}.log"),
              config.merge(workers: count))
            sample.merge!(warmup: warmup, pair: index + 1)
            report[:samples] << sample
            Base.write_report(directory, report)
            puts "#{label} #{sample[:passed] ? 'PASS' : 'FAIL'} wall=#{sample[:wall_seconds]} s rss=#{sample[:peak_tree_rss_mib]&.round(1)} MiB actual_workers=#{sample.dig(:worker_audit, :actual_workers)}"
            raise "Invalid sample: #{label}" unless sample[:passed] && sample[:wall_seconds].positive?
          end
        end
        report[:summary] = workers.to_h do |count|
          rows = report[:samples].select { |r| !r[:warmup] && r[:requested_workers] == count }
          [count, %i[wall_seconds cpu_seconds peak_tree_rss_mib tests_per_second].to_h { |key| [key, Base.stats(rows.map { |r| r.fetch(key) })] }]
        end
        baseline = report[:summary].fetch(1).fetch(:wall_seconds).fetch(:median)
        report[:summary].each do |count, metrics|
          metrics[:speedup] = baseline / metrics[:wall_seconds][:median]
          metrics[:parallel_efficiency] = metrics[:speedup] / count
          puts format("%2d workers: median %.3fs, %.2fx speedup, %.1f%% efficiency, %.1fMiB RSS",
            count, metrics[:wall_seconds][:median], metrics[:speedup], 100 * metrics[:parallel_efficiency], metrics[:peak_tree_rss_mib][:median])
        end
        report[:complete] = true
        Base.write_report(directory, report)
        puts "Results: #{directory}/results.json"
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

exit Petstore::ParallelBenchmark.main(ARGV) if $PROGRAM_NAME == __FILE__
