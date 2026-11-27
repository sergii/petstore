# frozen_string_literal: true

require "json"
require "open3"
require "domstride"

module PetstoreMemoryHook
  def reset_document!
    result = super
    @memory_reset_count = (@memory_reset_count || 0) + 1
    memory = dom_command("memory_state")
    rss, status = Open3.capture2("ps", "-o", "rss=", "-p", Process.pid.to_s)
    raise "Ruby RSS sample unavailable" unless status.success? && rss.strip.match?(/\A\d+\z/)
    stats = GC.stat.slice(:heap_live_slots, :heap_allocated_pages, :total_allocated_objects, :minor_gc_count, :major_gc_count)
    row = { reset: @memory_reset_count, ruby_pid: Process.pid, worker_pid: worker_pid,
      ruby_rss_bytes: rss.to_i * 1024, ruby_gc: stats, node: memory }
    File.open(ENV.fetch("PETSTORE_MEMORY_FILE"), "a", 0o600) { |file| file.puts(JSON.generate(row)) }
    result
  end
end

Domstride::Session.prepend(PetstoreMemoryHook)
