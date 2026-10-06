# Changelog

All notable changes to MessagePassingRulesBase.jl are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/releases/tag/v1.0.0
