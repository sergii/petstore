# Pet Store

A small second-hand pet marketplace and reference application for Domstride integration testing.

## Baseline

Ruby 4.0.10, Rails 8.1.4.1, SQLite, Propshaft, Importmap, Turbo, Stimulus, vanilla CSS. No Node.js or JS bundler. Rails-native authentication follows the Rails 8 generator pattern: database sessions, signed cookies, CurrentAttributes, bcrypt, login throttling and password reset tokens. Registration is an application extension. This is a minimal handwritten Rails skeleton, not output from a locally executed generator.

## Run locally

Install Ruby 4.0.10, then:

```sh
bin/setup
bin/rails db:seed
bin/rails server
```

Open http://localhost:3000. Demo credentials: demo@example.com / petstore-demo (development only; never seed a public production instance).

## Tests

```sh
bin/rails test
bin/rails test:system
```

System tests use Selenium and headless Chrome. Install Chrome locally. The fixture data is isolated from development seeds.

Scenarios: guest browsing/search, signup/signin/signout, listing lifecycle, validation, ownership, Stimulus description counter/price preview/password visibility, Turbo confirmation.

## Domstride experiment (draft)

The same original system tests run with either driver. Selenium remains the default.
Domstride is pinned to `f9e4cc04f020e0c48bb95576d486b9c15de2ccd4` on research/petstore-mount-profile (diagnostic-only instrumentation stacked on verified integration revision 0f7efe9825e385c05bc59839d388f188304d36e7). Node 22+ and npm are required only for the Domstride runtime.

```sh
bundle install
bundle exec domstride setup
bundle exec domstride doctor --json
bin/rails test:system
SYSTEM_TEST_DRIVER=domstride bin/rails test:system
```

The experiment uses the compatible profile (jsdom31) and the opt-in asset bundler to load the existing Rails Importmap scripts. It does not change the application's JavaScript build, tests or assertions. Unsupported behavior (including potentially the Turbo confirmation dialog) is a compatibility finding, not a reason to skip or weaken the original scenario. No automatic fallback. Do not merge until dependency resolution and results are reviewed.

Optional diagnostic run:

```sh
SYSTEM_TEST_DRIVER=domstride DOMSTRIDE_FAILURE_DIR=tmp/domstride-failures DOMSTRIDE_RECORD_DIR=tmp/domstride-recordings bin/rails test:system
```

Records are metadata-only by default. Do not enable HTML capture with sensitive data.

## System benchmark

Run `bundle exec ruby script/benchmark_system.rb` after dependency/runtime setup and test database preparation. See [benchmark methodology](docs/system-benchmark.md) for warmups, raw JSON, CPU and process-tree RSS metrics, and limitations.

## Experiment branches

Keep main as the Importmap reference. Add Domstride in a separate PR, then independently evaluate esbuild, Vite, Webpack and other bundlers with the same user flows. Do not change assertions just to make a driver pass.

## Scope and verification

This is a test application, not a production marketplace. Payments, messaging, photo uploads and email delivery configuration are intentionally out of scope. The dependency lockfile must be generated with Ruby 4.0.10 via bundle install and committed after verification. Run both test suites before treating this as a verified baseline.
