# Repository Guidelines

## Project Structure & Module Organization

This is a Perl client for NATS. Library code is under `lib/Net/NATS2/`, with
`Client.pm` as the primary public entry point and supporting protocol, message,
connection, and JetStream modules beside it. Tests live in `t/`; focused tests
such as `t/accessors.t` run without a server, while `t/nats.t`, `t/headers.t`,
`t/reconnect.t`, and `t/jetstream.t` exercise a NATS service. Runnable usage
examples are in `examples/`. Distribution metadata and dependencies are defined
in `Makefile.PL`; keep `MANIFEST` current when adding distributable files.

## Build, Test, and Development Commands

Run these from the repository root:

```sh
perl Makefile.PL       # generate the MakeMaker build files
make                   # copy/build the distribution
make test              # run the Perl test suite
./test.sh              # run Docker Compose NATS integration tests
make manifest          # regenerate MANIFEST after adding files
```

`./test.sh` starts the services defined in `docker-compose.yaml` and returns
the test container's status. Integration tests skip when NATS is unavailable,
so use the Docker command before relying on those results.

## Coding Style & Naming Conventions

Target Perl 5.10.1 and retain `use v5.10`, `use strict`, and `use warnings` in
modules and tests. Follow `.perltidyrc`: Perl Best Practices baseline, four-space
indentation and continuation indentation, and a 120-column limit. Format changed
Perl files with `perltidy -pro=.perltidyrc path/to/file.pm`. Name modules by
their package path (for example, `Net::NATS2::ServerInfo` in
`lib/Net/NATS2/ServerInfo.pm`) and tests with descriptive lowercase names such
as `t/headers.t`. Use `Test::More` assertions with behavior-oriented messages.

## Testing Guidelines

Add or update a focused `t/*.t` file for every behavior change. Keep tests
independent, call `done_testing`, and cover protocol edge cases without relying
on execution order. Run `make test` for quick feedback, then the Compose suite
when changing connection, publish/subscribe, reconnection, header, or JetStream
behavior.

## Commit & Pull Request Guidelines

Recent history uses short imperative release-oriented subjects, for example
`Fix tests` and `Update Pod info`. Keep commits similarly focused and describe
the observable change. Pull requests should summarize behavior and tests run,
link the relevant issue when applicable, and include documentation or POD
updates for public API changes. Include logs or a small reproduction for
protocol regressions; screenshots are not normally relevant to this library.
