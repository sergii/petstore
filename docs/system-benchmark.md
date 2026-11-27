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


## Mount-phase evidence and experiment A (2026-11-27)

User local diagnostic f9e4cc0: 3 tests, 15 assertions, 0 errors/failures/skips. Suite 3.411773s. Three mounts 2576.19ms Ruby round-trip, 1627.63ms worker wall. Boot 789.78ms, assets total 1366.73ms (including esbuild/Rack/rewrite 750.79ms, secondary parser require 446.78ms, preparse 147.62ms), window creation 211.77ms, module eval 40.22ms. 43 Rack requests / 182.20ms total. Phase timers overlap; not CPU attribution.

Experiment A pin ecfb202557f7c0cb0071c1f1693f5e95026ab625 (Domstride PR #12): reuse the active engine's JSDOM constructor for inert asset discovery, avoiding loading a second version. No other optimization. Run bundle install, domstride setup, profile_system.rb and the normal benchmark with the same settings. Compare to the original sequential baseline, noting the added diagnostics are disabled during the normal benchmark. Raw V8 profiles not yet provided. Verify regression suite and parity before merging. Keep lockfile updated locally after dependency resolution.


## OPT-001 verified sequential result (2026-11-27)

At ecfb202 / Pet Store 332f03d, 24 invocations passed. Median/p95 wall s Selenium 3.645/4.280 vs Domstride 2.705/3.000; CPU s 2.825 vs 3.340; sampled RSS MiB 1562.6 vs 346.6. Relative to original Domstride baseline: wall -12.6%, CPU -14.9%, RSS -9.1%. Selenium also changed across series, so the speedup change 1.055x to 1.348x is not wholly attributable to the optimization. Profile showed secondary parser load reduced from 446.78 to 0.03ms, boot 653.92ms, assets 824.71ms, esbuild/Rack/rewrite 634.35ms. All 3 tests/15 assertions pass. Raw JSON not supplied.

## OPT-002: persistent worker (experimental)

Pinned ebb6aa312a91f1ea25bb46041ee74145d8ed75df, Domstride PR #13. Default behavior remains unchanged. Compare the same pin and settings with flag off and on:

```sh
bundle exec ruby script/profile_system.rb
bundle exec ruby script/profile_system.rb --reuse-worker
bundle exec ruby script/benchmark_system.rb
bundle exec ruby script/benchmark_system.rb --reuse-worker
```

Profile summary reports sessions and PIDs; successful reuse should reduce the number of distinct worker PIDs and engine boot count. Pending requests or modal scopes block reset; no silent retry. Node/jsdom only, real clock, no websocket or recording. Fresh DOM and Rack cookie session do not guarantee full process isolation; shared host prototypes/modules may retain state. Test separately before default changes. No original system tests modified. Results pending; lockfile must be regenerated by bundle install.


## OPT-002 verified profile, isolation and sequential benchmarks (2026-11-27)

User-reported Pet Store 426c7eb, Domstride ebb6aa3. Benchmark runner unit tests 5/22. Persistent-worker isolation regression 1/10. Both profiled runs and all 48 sequential benchmark invocations (8 warmups, 40 measured) passed unchanged system tests (3 runs / 15 assertions each). No skips, failures or errors.

| Profile metric | Fresh | Persistent |
|---|---:|---:|
| Suite s | 2.442873 | 1.158141 |
| Distinct workers | 3 | 1 |
| Mount round-trip ms | 1677.83 | 512.95 |
| Boot ms | 693.61 | 230.98 |
| Asset preparation ms | 778.86 | 215.39 |
| esbuild/Rack/rewrite ms | 581.50 | 132.48 |
| Rack requests | 43 | 43 |
| Reset calls / wall ms | n/a | 3 / 0.90 |

| Series / driver | Median wall s | p95 wall s | CPU s | Peak sampled RSS MiB |
|---|---:|---:|---:|---:|
| Fresh series Selenium | 3.275 | 3.770 | 2.610 | 1595.6 |
| Fresh Domstride | 2.570 | 2.670 | 3.230 | 346.1 |
| Persistent series Selenium | 3.565 | 5.640 | 2.810 | 1549.9 |
| Persistent Domstride | 2.005 | 3.380 | 2.415 | 367.5 |

Fresh vs persistent across series: wall -22.0%, CPU -25.2%, RSS +6.2%, p95 +26.6%. Persistent series vs its Selenium control: 1.778x wall speedup, 43.8% less wall time, 14.1% less accounted CPU, 76.3% lower sampled RSS. Persistent measured wall samples: 3.38, 2.79, 2.15, 3.03, 2.33, 1.81, 1.86, 1.85, 1.80, 1.70 s. Fresh: 2.66, 2.66, 2.66, 2.53, 2.58, 2.50, 2.67, 2.56, 2.56, 2.54 s. The final five persistent runs have median 1.81 s, but all samples count. Selenium also slowed during persistent series, with 5.64s maximum. Cause of variability unknown; do not discard first five samples. Raw CPU JSON and V8 files not supplied. Profile speedup 2.109x is not the uninstrumented speedup.

## Direct paired worker reuse A/B

Run the same Domstride revision with fresh and persistent modes alternating within each seed pair, without Selenium. This is a more direct comparison than consecutive independent benchmark series, though not a guarantee against background workload or thermal variation.

```sh
bundle exec ruby test/benchmarks/worker_reuse_benchmark_test.rb
bundle exec ruby script/benchmark_worker_reuse.rb --warmup 2 --runs 20
```

The runner reuses the original measurement and correctness checks, records each mode and reuse flag, and reports median/p95 for each metric plus median of within-pair wall ratios, seconds saved, and persistent wins. Every measured pair is retained. No dependency pin or runtime change. Output tmp/system-benchmarks/reuse-ab-*/results.json. Remain opt-in pending wider regression, long-running memory and isolation tests. Next optimization candidate: Importmap cache, only if correctness and measurable residual asset overhead justify it. Existing warmed esbuild time is already low; no cache implementation yet.


## OPT-002 paired A/B verified (2026-11-27)

Pet Store ea1b99a, Domstride ebb6aa3: runner 3/9, all 44 invocations passed (20 measured pairs, 2 warmup pairs). Fresh/persistent: median wall 2.645/1.765s, p95 3.750/2.840s, CPU 3.300/2.185s, sampled RSS 347.4/368.5MiB. Paired median speedup 1.516x, median saved 0.895s, wins 19/20. Wider isolation and long-running RSS checks remain necessary. Raw JSON not supplied.

## OPT-003: revalidated Importmap cache

Pinned aa34bae597f15c41a517f783557f652d59c061af. Strict warning mode, opt-in. Cache only compiled module output, re-fetch all dependencies from Rack and verify exact content and URL before serving compiled code. Does not skip Rack requests or cache HTML. At most two entries; no disk cache. Read-only assets only (request order may change). Same-document-URL key may limit hit rate. Compare profile counters and then paired cache A/B with persistent worker enabled for both modes:

```sh
bundle exec ruby "$(bundle show domstride)/test/assets_test.rb"
bundle exec ruby script/profile_system.rb --reuse-worker --importmap-cache
bundle exec ruby script/benchmark_worker_reuse.rb --importmap-cache --warmup 2 --runs 20
```

The last command compares cache-off vs cache-on; the JSON key persistent_wins is retained for backward compatibility and counts wins of the second mode. No benchmark evidence yet. Keep cache off by default. Do not assume the cache saves CPU or time until measured.
