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
