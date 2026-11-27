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

## Experiment branches

Keep main as the Importmap reference. Add Domstride in a separate PR, then independently evaluate esbuild, Vite, Webpack and other bundlers with the same user flows. Do not change assertions just to make a driver pass.

## Scope and verification

This is a test application, not a production marketplace. Payments, messaging, photo uploads and email delivery configuration are intentionally out of scope. The dependency lockfile must be generated with Ruby 4.0.10 via bundle install and committed after verification. Run both test suites before treating this as a verified baseline.
