# frozen_string_literal: true

# Explicitly loaded by the benchmark runner, not by ordinary test discovery.
require_relative "../system/marketplace_test"

repeats = Integer(ENV.fetch("PETSTORE_SUITE_REPEATS"))
raise ArgumentError, "Scaled workload requires at least two repeats" if repeats < 2

# Keep the original scenario bodies and normal Rails setup/teardown.
# Each generated test is a separate Minitest invocation; no inner test loop.
class MarketplaceSystemTest
  originals = instance_methods(false).grep(/\Atest_/).sort
  raise "Expected three original marketplace tests, found #{originals.size}" unless originals.size == 3

  methods = originals.to_h { |name| [name, instance_method(name)] }
  originals.each { |name| remove_method(name) }
  repeats = Integer(ENV.fetch("PETSTORE_SUITE_REPEATS"))
  repeats.times do |index|
    methods.each do |name, implementation|
      define_method("#{name}__scale_#{format('%04d', index + 1)}", implementation)
    end
  end
end


# Only the parallel benchmark activates Rails process parallelism and auditing.
if ENV["PETSTORE_WORKER_AUDIT"]
  require "json"
  class MarketplaceSystemTest
    parallelize(workers: Integer(ENV.fetch("PARALLEL_WORKERS")), with: :processes, threshold: 0)

    def after_teardown
      super
      row = { pid: Process.pid, test: name, database: ActiveRecord::Base.connection_db_config.database }
      File.open(ENV.fetch("PETSTORE_WORKER_AUDIT"), "a", 0o600) do |file|
        file.flock(File::LOCK_EX)
        file.puts(JSON.generate(row))
      end
    end
  end
end
