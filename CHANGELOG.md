# Changelog

All notable changes to MessagePassingRulesBase.jl are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.3] - 2026-10-25

### Changed

- The suite runs weekly, and on demand, on the latest Julia with the latest release of every
  dependency (`Weekly.yml`); the guide *Your own rule package* says so, as the template has it.
- The test-only compat entry for JET admits 0.13, which needs Julia 1.12; on 1.10 and 1.11 the
  suite keeps an earlier JET.

## [1.1.2] - 2026-10-18

### Fixed

- A `NodeFunctionRuleFallback` message no longer allocates when evaluated: it built its node
  function's keyword arguments at run time on every call, 700 ns and 16 allocations where the node
  function takes a few nanoseconds, so a projection of many of them took minutes (#13).

## [1.1.1] - 2026-10-15

### Changed

- The documentation's guide *Your own rule package*: a rule package starts from the template,
  [MessagePassingRulesTemplate.jl](https://github.com/ReactiveBayes/MessagePassingRulesTemplate.jl),
  which the overview, *Your first node*, *Defining rules* and the README now point to. The README
  no longer lists the dependencies.

## [1.1.0] - 2026-10-06

### Added

- `logscale = improper`, a declaration for a message rule whose message has no normalising
  constant, as an exact message may: its log scale is an `UndefinedLogScale` whose cause is
  `:improper`, and `require_logscale` says that none exists, where an omitted `logscale` says that
  the log scale is not known (#9).
- A tutorial, *A new message passing scheme*: natural-gradient message passing for a Poisson count
  with a log rate, as an algorithm, a dependency declaration and a rule (#9).
- A Makefile: `make test` (as CI runs it, with `test_args` to select items), `test-fast`, `docs`,
  `docs-serve`, `format`, `check-format`, `clean` (#9).

### Changed

- Documentation, from the review in #9: what a pure rule may and may not do; what the registry is
  for, with an example; *resolution* defined in the glossary and linked; improper messages on the
  *Log scales* page; a shorter first example on the overview; the expectation propagation entry
  pointing to the tutorial that builds such a rule; and an example in *Algorithms and
  dependencies* told through its own node.
- Tests cover the in-place marginal API, `message_passing_marginalrule!`, and the other paths
  that had none, and two unreachable internal helpers are gone (#12).

## [1.0.0] - 2026-10-05

The first release: the rule system of the ReactiveMP ecosystem, developed in the
[ReactiveMP](https://github.com/ReactiveBayes/ReactiveMP.jl) repository, whose history this
repository keeps.

[Unreleased]: https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/compare/v1.1.3...HEAD
[1.1.3]: https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/releases/tag/v1.0.0
