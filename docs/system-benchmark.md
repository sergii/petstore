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


## OPT-003 paired A/B results (2026-11-27)

User-reported Pet Store ff7c300, Domstride aa34bae. Assets regression 8 runs / 36 assertions, benchmark runner 5/24, system profile 3/15, all passing. Cache profile: one hit, two misses, 43 Rack requests, 1.135734s suite, mount 461.57ms, assets 181.13ms, esbuild/Rack/rewrite 97.72ms, cache revalidation 6.34ms.

Both paired modes use persistent worker. All 44 invocations passed, including four warmups.

| Metric | Cache off | Cache on |
|---|---:|---:|
| Median wall seconds | 1.710 | 1.715 |
| p95 wall seconds | 1.830 | 2.060 |
| Median CPU seconds | 2.150 | 2.095 |
| Median sampled peak RSS MiB | 370.4 | 360.5 |

Median paired speedup 1.009x, paired seconds saved 0.015, cache wins 11/20. No meaningful demonstrated wall-time improvement; p95 worse, small CPU/RSS difference. Keep experimental and off by default. A larger suite may change hit rate; no aggressive cache redesign without evidence. Raw JSON not supplied.

## Scaled sequential workload

Use original three marketplace scenarios repeated as independent test methods, with standard Rails test lifecycle and seeded randomized execution. This is synthetic repeated workload, not hundreds of unique behaviors. Existing test source and ordinary test discovery are unchanged. The benchmark runner calculates expected counts (3 tests and 15 assertions per repeat), rejects any failure/error/skip or count mismatch, and keeps cache off unless explicitly requested.

```sh
# Smoke: 30 tests / 150 assertions per invocation
bundle exec ruby script/benchmark_system.rb --reuse-worker --suite-repeats 10 --warmup 0 --runs 1 --timeout 180

# 102 tests / 510 assertions per invocation
bundle exec ruby script/benchmark_system.rb --reuse-worker --suite-repeats 34 --warmup 1 --runs 3 --timeout 600

# Longer runs, after smaller workload passes
bundle exec ruby script/benchmark_system.rb --reuse-worker --suite-repeats 167 --warmup 0 --runs 1 --timeout 1800
bundle exec ruby script/benchmark_system.rb --reuse-worker --suite-repeats 333 --warmup 0 --runs 1 --timeout 3600
```

The same flag works with benchmark_worker_reuse.rb for direct fresh/persistent comparison. Each invocation is a fresh Rails process; within a persistent invocation the Node worker remains alive across independent test resets. All use one Rails worker. Output now includes tests_per_second and roughly one-second RSS trace alongside sampled peak RSS. RSS is not unique memory or proof of a leak; compare growth and plateau across longer runs. This step measures sequential scalability, not parallel scalability. A single run is exploratory, not a robust median. No new dependency or Domstride runtime changes. Execution and larger-suite fixture isolation still need verification.


## Scaled sequential benchmark evidence and memory investigation (2026-11-27)

Source: user-supplied complete 30-test and partial 102-test results.json. Both captured at Pet Store d905ef17e800066d1c3c71d5ccc14fb173b73c19, Domstride aa34bae597f15c41a517f783557f652d59c061af, Ruby 4.0.10 arm64-darwin25, Node v26.7.0, 10 logical CPUs. Same lock SHA256 c207cc87a6bdcccec9a1ba234a0eb8ad7838d86fd6cdc1bab4d2330cec8f8165; tracked worktree had modified Gemfile.lock at capture. One Rails worker, compatible jsdom31, persistent on, Importmap cache off, Selenium browser pin 157.0.8103.78. No claim of clean checkout at capture.

| Tests | Seed | Driver | Wall s | Suite s | Accounted CPU s | Sampled peak tree RSS MiB | Result |
|---:|---:|---|---:|---:|---:|---:|---|
| 30 | 1081 | Selenium | 18.910 | 17.798411 | 20.440 | 3219.953125 | 30/150 pass |
| 30 | 1081 | Domstride | 6.570 | 5.679919 | 7.580 | 539.484375 | 30/150 pass |
| 102 | 1081 | Selenium | 56.150 | 55.263531 | 73.240 | 3360.125 | 102/510 pass, warmup |
| 102 | 1081 | Domstride | 17.010 | 16.111938 | 18.610 | 755.484375 | 102/510 pass, warmup |
| 102 | 1082 | Domstride | 16.620 | 15.980686 | 18.360 | 750.390625 | 102/510 pass |
| 102 | 1082 | Selenium | 56.370 | 55.338469 | 72.220 | 3294.500 | 102/510 pass |
| 102 | 1083 | Selenium | 26.600 | 25.575203 | 30.360 | 3327.500 | 102 tests, 225 assertions, 60 errors, exit 1 |

30-test single-pair speedup 2.878x; 102-test successful measured pair 3.392x, accounted CPU reduction 74.6%, sampled RSS reduction 77.2%. The 102-test experiment was incomplete: only one measured pair completed; no aggregate speedup, p95 or stability claim. The failed sample had no timeout, no exit signal, 0 assertion failures, 60 errors and 0 skips. No exception details supplied. Do not infer browser crash or OOM from RSS or error count. Seed 1083 Domstride was not executed because runner correctly aborted.

Memory traces: Selenium successful 102-test run reaches ~3.1 GiB around 8-10 s and stays broadly near that range until teardown (13.405s 3294.50MiB; 30.756s 3151.64MiB; 55.239s 3097.39MiB). Domstride measured 102-test trace grows from 421.69MiB at 2.182s to 569.78MiB at 5.538s, 656.48MiB at 10.013s and 750.39MiB at 16.590s. Warmup exhibits similar growth (358.80MiB at 2.039s, 616.98MiB at 9.722s, 755.48MiB at 16.294s). Domstride 30-test trace ends at 537.08MiB at 6.081s. No plateau established for Domstride; neither heap leak nor its absence established. Whole-tree RSS includes shared pages, Ruby, Node, esbuild and other descendants; no per-process attribution. CPU accounting also may exclude detached work.

Next gates:
1. Inspect first exception and grouped exception signatures in 03-measured-selenium.log (not yet supplied); reproduce same seed if appropriate, with exact pinned browser. Preserve failed sample and do not silently retry or loosen tests.
2. Compare sequential fresh/persistent Domstride at 102 tests without Selenium using existing paired runner. Separate diagnostic runs with per-process RSS, V8 heapUsed/heapTotal/external/arrayBuffers and completed-test/reset count. Check retained DOM, handles, async callbacks and Rack session lifecycle. Optional explicit GC only in a separate diagnostic, not performance measurements.
3. Stress 501/999 independent test invocations, retain full traces and parity; consider bounded worker recycling only if continued growth is established. Wider regression and parallel scaling remain pending. No runtime change in this evidence update.



## Selenium session-loss finding (seed 1083, 2026-11-27)

Source: supplied first 150 lines of 03-measured-selenium.log. Chrome 157.0.8103.78, selenium-webdriver 4.54.0, Capybara 3.40.0, Action Pack 8.1.4.1, Puma 8.1.3. The progress output shows 42 successful tests before the first error, in MarketplaceSystemTest#test_password_visibility_and_sign_in__scale_0028 at test/system/marketplace_test.rb:36. First exception: Selenium::WebDriver::Error::InvalidSessionIdError: invalid session id: session deleted as the browser has closed the connection; from disconnected: Unable to receive message from renderer. Subsequent screenshot (before_teardown) and session reset (after_teardown) attempts fail with InvalidSessionIdError. Following scenarios also encounter invalid session IDs. Together with partial results.json (102 tests, 225 assertions, 60 errors, no assertion failures, exit 1, no timeout), this supports a cascading session-loss failure, not 60 independent application defects. The underlying cause of renderer disconnection remains unknown. No evidence establishes OOM or a particular Chrome bug.

Preserve failed benchmark; do not replace it with a successful retry. Reproduce in a separate diagnostic log with the same seed, workload and pinned browser (single Rails worker):

```sh
set -o pipefail
mkdir -p tmp/system-diagnostics
SYSTEM_TEST_DRIVER=selenium RAILS_ENV=test PARALLEL_WORKERS=1 PETSTORE_SUITE_REPEATS=34 \
  SE_BROWSER_VERSION=157.0.8103.78 SE_TIMEOUT=900 SE_SKIP_DRIVER_IN_PATH=true SE_FORCE_BROWSER_DOWNLOAD=true \
  bundle exec rails test test/scale/marketplace_workload.rb --seed 1083 --verbose \
  2>&1 | tee "tmp/system-diagnostics/selenium-seed1083-$(date +%Y%m%d-%H%M%S).log"
```

This is diagnostic, not comparable timing (verbose logging and no RSS sampler). Review environment overrides before reproducing; original benchmark runner sanitizes driver environment. Do not retry failed tests inside measured samples or silently recreate a failed browser. If repeated failure, collect browser/renderer crash diagnostics and OS memory-pressure evidence before changing versions/flags. A successful repeat does not invalidate prior failure.

Independent Domstride scale experiment remains unblocked: run existing paired fresh/persistent benchmark at 102 tests, cache off, same pin, and inspect memory traces. Separate diagnostic memory measurements (Ruby/Node RSS, V8 heap metrics and completed reset count) remain planned.

Domstride reliability requirement: failure containment at test boundaries. Report original failed test, preserve error evidence, make secondary diagnostics best-effort, retire a broken worker and use a fresh isolated worker for subsequent tests if policy allows; never silently replay a failed command or test. Benchmark mode remains strict and records failures. Add fault-injection tests for worker termination, pending request, reset failure and cleanup; distinguish infrastructure errors from assertion failures. This is a proposed requirement, not a verified recovery capability.


## OPT-002: 102-test paired worker reuse result

User-reported complete run, 102 tests / 510 assertions per invocation, aa34bae. All eight invocations passed (one warmup pair and three measured pairs).

| Mode | Median wall s | p95 wall s | CPU s | Sampled peak RSS MiB |
|---|---:|---:|---:|---:|
| Fresh | 71.320 | 73.770 | 89.890 | 348.1 |
| Persistent | 19.560 | 20.010 | 20.290 | 675.7 |

Measured paired fresh/persistent wall: 71.32/18.40, 73.77/19.56, 65.11/20.01 s. Median paired speedup 3.771x, median paired seconds saved 52.920, wins 3/3. Persistent wall median -72.6%, CPU -77.4%, sampled peak RSS +94.1%. Three measured pairs only; p95 equals maximum. Distinct from prior Selenium comparison, which remains incomplete. Raw results.json and RSS traces for this direct experiment not supplied.

## MEM-001: explicit post-reset memory diagnostic

Pinned dd735a4dea4874c7ca175e1a915fd3897f951583 (Domstride PR #15). Dedicated runner samples natural Node process memory and counters after each successful reset; Ruby RSS and GC stats separately. No forced GC. Validates exact test/assertion counts, one PID per runtime, one sample per reset and empty document/handles/pending/fetch state. Records JSONL and complete results.json. Does not sample esbuild child RSS; retain previous whole-tree trace for comparison. Diagnostics add overhead and must not be treated as speed measurements. No memory recycling or default change.

```sh
bundle exec ruby test/benchmarks/memory_diagnostic_test.rb
bundle exec ruby "$(bundle show domstride)/test/persistent_worker_test.rb"
bundle exec ruby script/diagnose_memory.rb --suite-repeats 34
# Only after the smaller diagnostic succeeds:
bundle exec ruby script/diagnose_memory.rb --suite-repeats 167
```

Inspect per-reset Node heapUsed, heapTotal, RSS, external, arrayBuffers and Ruby RSS/GC counters for plateau or continued growth. No conclusion about retained objects without further GC/heap analysis. Regression and execution pending.


## MEM-001 verified; Selenium diagnostic rerun (2026-11-27)

User-reported console output, Pet Store 981fa0f, Domstride dd735a4. Diagnostic runner unit tests 3/7 and persistent worker regression 1/21 passed, no failures/errors/skips. Natural GC, Importmap cache off, one Rails worker. The memory runner completed 102/102 and 501/501 reset samples, with exact assertion parity and its single-PID, empty-document, empty-handles and pending/fetch checks. These are instrumented Minitest suite times, not external wall time benchmarks.

| Workload | Suite seconds | Tests/s | Assertions | Reset samples |
|---|---:|---:|---:|---:|
| 102 | 19.047159 | 5.3551 | 510 | 102/102 |
| 501 | 83.982107 | 5.9656 | 2505 | 501/501 |

All system tests passed, no failures/errors/skips. Summary values below are post-reset sampled MiB, not continuous process peaks.

| Metric | 102 first | 102 last | 102 max | 501 first | 501 last | 501 max |
|---|---:|---:|---:|---:|---:|---:|
| Node RSS | 151.77 | 500.73 | 521.03 | 167.11 | 611.39 | 791.98 |
| V8 heapTotal | 74.52 | 350.73 | 436.72 | 88.52 | 480.45 | 535.94 |
| V8 heapUsed | 58.64 | 99.88 | 383.46 | 49.93 | 323.49 | 486.00 |
| Node external | 7.34 | 6.66 | 13.57 | 6.63 | 11.36 | 15.98 |
| Node arrayBuffers | 1.99 | 1.32 | 8.22 | 1.28 | 6.01 | 10.63 |
| Ruby RSS | 119.75 | 141.84 | 145.47 | 120.94 | 132.75 | 147.45 |

4.91x as many tests with 1.52x sampled max Node RSS, 1.27x max heapUsed, and 1.014x max Ruby RSS across separate runs. In the 501-test run last heapUsed was 162.52 MiB below sampled max, consistent with GC reclamation. This does not establish a plateau or prove absence of retained objects. First/last/max are not a time series; no per-reset raw results.json has been supplied. Node RSS excludes esbuild child and Ruby, unlike earlier whole-tree measurements. External includes arrayBuffers; do not add them. No forced GC, memory leak attribution, or cross-workload memory budget claim.

Selenium diagnostic reproduction with seed 1083 and pinned Chrome 157.0.8103.78 passed 102 tests / 510 assertions, 0 failures/errors/skips, suite 78.557545s. The previously failing password visibility test scale_0028 also passed. Session loss was not reproduced on this one attempt; intermittent infrastructure failure remains documented, underlying cause unknown. Verbose diagnostic timing is not a benchmark. Do not overwrite the failed sample or claim the browser issue is fixed.

Next gates: obtain both per-reset memory results.json files and inspect heapUsed troughs, heapTotal/RSS evolution, and reset counters; repeat on 999 tests with current diagnostic; only then consider a separate periodic forced-GC experiment if trends remain ambiguous. Do not force GC in regular benchmarks. Run a separate uninstrumented 501-test Selenium/persistent comparison after checking available memory; maintain exact parity and retain failed samples. Recovery and worker recycling remain proposed, not implemented. No runtime change in this evidence update.


## Full memory traces: stop criteria and next phase (2026-11-27)

Analyzed both user-supplied complete memory results.json files, 102 and 501 samples (603 total). Same Domstride dd735a4 and lock SHA256 f587c5a3b429778a493b904046a34adb457cd06819407fdb2183da3ff5cc4ee0; Pet Store revisions 981fa0f (modified lockfile) and e7afdef (clean checkout), respectively. Both passed exact test/assertion counts. In each run, one Ruby PID, one Node PID, contiguous reset sequence. All 603 samples have zero handles, pending requests, active fetches and error listeners; has_document and confirm_armed false.

501-test run, per-block statistics in MiB:
| Resets | Median Node RSS | Max Node RSS | Min heapUsed | Median heapUsed |
|---|---:|---:|---:|---:|
| 1-100 | 413.0 | 533.4 | 49.9 | 184.9 |
| 101-200 | 537.2 | 590.8 | 120.6 | 273.1 |
| 201-300 | 614.0 | 792.0 | 121.7 | 278.3 |
| 301-400 | 619.7 | 748.4 | 103.5 | 260.4 |
| 401-501 | 598.5 | 646.2 | 122.0 | 280.0 |

Maximum sampled Node RSS at reset 276, not at suite end. Last-block median RSS lower than preceding block. Natural heap troughs broadly stable after first 100 resets; these are not forced-GC retained-heap measurements. Evidence suggests a warmup/plateau rather than continuous monotonic growth on this synthetic workload. Does not establish absence of slow leaks, full JS isolation, or production memory limits.

Recommendation: end the escalating sequential soak loop for this phase at 501 tests; 999/10,000 repeats are optional later release/soak checks, not mandatory gates without a new hypothesis. Next characterize actual parallel scaling on a fixed workload (102 or 501 tests) with 1/2/4/8 workers and optionally 10 on the measured 10-logical-CPU host, verifying actual worker counts and database isolation; same workload, seeds, assertions, and runtime settings, paired Selenium where feasible, no forced GC or diagnostic hook in timed runs. Measure wall, throughput, aggregate process-tree RSS, CPU accounting caveats, errors, speedup and parallel efficiency. Stop increasing workers when throughput plateaus/regresses or memory budget is exceeded. Wider compatibility and reliability fault injection should follow before production defaults. No code/runtime changes in this evidence update.


## CI-driven experiments (2026-11-27)

Domstride system tests passed on Ubuntu CI at b354646; Selenium system tests failed before assertions with SessionNotCreatedError (Chrome instance exited). Root cause not established. Enable Selenium Manager debug and Chrome log artifact on CI only; retain exact browser pin and sandbox behavior. The existing Selenium comparison stays strict and separate.

Domstride Experiments workflow runs independently on pushes changing experiment code: compatibility, paired 102-test worker reuse, 501-test memory diagnostics, and parallel scalability. JSON and logs uploaded even on failures. Two measured runs per configuration are exploratory; compare within one runner only, not absolute timings against macOS. Endurance and fault-injection jobs remain future work.

Parallel runner uses Rails process parallelization with isolated test databases, same 102-test workload, exact counts, alternates worker-count order and audits every test's PID and database path. Audit requires all requested processes to execute tests, unique test identities and distinct databases; failed samples retained, no speedup on incomplete run. Initial CI: 1/2/4 workers on same runner, one warmup and two measured rounds, Domstride persistent/cache off. Eight workers optional via --workers 1,2,4,8 after reviewing memory and actual runner capacity. Selenium mode available separately after startup issue diagnosed. Audit adds small file IO and reports requested vs actual Rails workers, not verified Node PID count. No runtime dependency change. Not yet executed at authoring time.

```sh
bundle exec ruby script/benchmark_parallel.rb --workers 1,2,4 --suite-repeats 34 --warmup 1 --runs 2
```
