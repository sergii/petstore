# System test benchmark

## Local execution

From the experiment branch, with Ruby 4.0.10, Node and npm installed:

```sh
bundle install
bundle exec domstride setup
RAILS_ENV=test bin/rails db:prepare

# Quick smoke run
bundle exec ruby script/benchmark_system.rb --warmup 1 --runs 2

# Standard benchmark: 2 warmups and 10 measured runs per driver
bundle exec ruby script/benchmark_system.rb
```

The first Selenium warmup can download the isolated Chrome for Testing 157 binary. If that exceeds the default 180-second invocation timeout, use `--timeout 900` or prewarm with `bin/rails test:system`. Runtime setup and warmups are excluded from the summary. Use `--help` for options. Run on an otherwise idle machine, with the same power mode and Ruby/Node versions.

## Method

- Same unchanged system test suite, three tests and 15 assertions, no skips/errors/failures.
- Fresh process per run, single Rails worker, same seed within each driver pair, alternating order across pairs.
- Fixed compatible jsdom31 profile with Importmap asset bundling, recording and profiling disabled; Selenium uses isolated Chrome 157. Ambient driver settings are cleared except cache paths. This is an end-to-end comparison of current driver configurations, not an isolated JS-engine benchmark.
- Wall time includes Rails and driver startup, measured via portable `/usr/bin/time -p`; Rails-reported suite time is stored separately.
- CPU seconds = user + system from `time -p` (OS waited-child accounting; detached work may be excluded).
- Peak memory is the maximum sampled concurrent sum of RSS for the child process group and visible descendants (100 ms nominal interval). It is not unique memory or an exact kernel peak; shared pages may be counted more than once and short-lived processes may be missed.
- Median, mean, min, max and nearest-rank p95 for each metric. With ten samples p95 is the maximum; use more runs for stronger tail estimates.
- Any nonzero exit, timeout, missing summary/measurement or unexpected test/assertion counts aborts the experiment and preserves partial logs. No speedup is emitted for partial runs.
- Output: `tmp/system-benchmarks/<timestamp>-<pid>/results.json` and per-invocation logs. JSON includes warmups, all raw samples, configuration, runtime versions, git commit and lock digest. Files are ignored by Git. Treat logs as test data.

## CI

The separate System Benchmark workflow runs on relevant benchmark-file PR changes and can be manually dispatched after the workflow exists on the default branch. GitHub-hosted runners are useful for smoke checks and artifacts; noisy runner performance should not be treated as a release threshold.

## Known integration evidence (2026-11-27)

User-reported macOS Apple Silicon, Ruby 4.0.10, Rails 8.1.4.1, Node 26.7.0. Pet Store experiment at ac910e1, Domstride 0f7efe9. Selenium: 3.261522 s; Domstride: 2.919743 s, both 3 runs / 15 assertions / zero failures, errors or skips. These are single Rails-reported suite times, **not** results of this benchmark runner. No full browser parity is claimed.


## Completed sequential benchmark (2026-11-27)

User-reported local run at e168e2d, pinned Domstride 0f7efe9. All 24 invocations passed (4 warmups, 20 measured). Each driver executed 30 measured tests and 150 assertions. Runner unit tests: 5 runs, 18 assertions, zero failures/errors/skips.

| Metric | Selenium | Domstride |
|---|---:|---:|
| Median wall s | 3.265 | 3.095 |
| p95 wall s | 3.760 | 3.180 |
| Median CPU s | 2.610 | 3.925 |
| Median sampled peak RSS MiB | 1578.2 | 381.2 |

Wall speedup 1.055x, sampled RSS -75.8%, CPU +50.4%. Raw CPU samples/JSON not supplied. No parallel scalability claim yet.

## Next: diagnostic profile (not benchmark timing)

```sh
bundle exec ruby test/benchmarks/profile_system_test.rb
bundle exec ruby script/profile_system.rb
bundle exec ruby script/profile_system.rb --node-cpu
```

The first profile uses Domstride's existing command-level instrumentation, collects each closed worker's counters, and records Ruby process CPU totals. The optional V8 CPU profile requires a Node version accepting --cpu-prof and --cpu-prof-dir in NODE_OPTIONS; use Chrome DevTools Performance or another compatible local viewer to inspect .cpuprofile files. Worker wall time includes asynchronous waits and can overlap Rack work and Ruby round-trip time; these are not disjoint CPU categories. Bundle hit/miss counters refer to the existing classic-script cache, not Importmap graph caching.

Output under tmp/system-profiles: sessions.jsonl, summary.json, system.log and optional .cpuprofile files. Instrumentation is opt-in and does not alter original test scenarios or normal benchmark configuration. Local CPU profiles may expose source paths and function names; do not publish automatically. Profile scripts are not a substitute for the uninstrumented benchmark.


## First profile evidence (2026-11-27)

At f4750a7, Domstride 0f7efe9, both ordinary and Node CPU-profile runs passed 3/15. Internal profile test passed 1/5. Mount dominated command round-trip wall time: 3 calls, 2296.86 ms of roughly 2825 ms aggregate command time (~81%). Worker mount wall 1149.51 ms. Second profile: 2228.26 / 1213.14 ms. Both runs issued 43 Rack requests; total Rack time 220.50 / 195.63 ms. Find handles 68 calls, 217.68 / 213.27 ms. Raw V8 CPU files not supplied. Do not interpret wall-time difference as pure IPC or CPU.

Next diagnostic revision f9e4cc04f020e0c48bb95576d486b9c15de2ccd4 adds boot and nested mount phase measurements (Domstride PR #11). Run bundle install and domstride setup after pulling the pin, then profile_system.rb. Original verified timing baseline remains the earlier pin 0f7efe9; this diagnostic run does not replace it. Do not add a stale lockfile or claim new benchmark parity until actual tests pass. No optimization has been made yet.
