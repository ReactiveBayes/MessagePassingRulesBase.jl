```@meta
CurrentModule = MessagePassingRulesBase
```

# [Your own rule package](@id rule-package)

The nodes and rules you define are ordinary Julia code, so they live in a package. Every
ReactiveBayes rule package has the same layout, and the standard way to start one is the
template, [MessagePassingRulesTemplate.jl](https://github.com/ReactiveBayes/MessagePassingRulesTemplate.jl).
It is a working package with one example node, whose tests, documentation and CI already pass.
You replace the node with yours.

## Start from the template

1. On [the template's page](https://github.com/ReactiveBayes/MessagePassingRulesTemplate.jl),
   choose **Use this template** and create a repository named `<Node>MessagePassingRules.jl`,
   after the node or the family of nodes it holds.
2. Clone it and run the setup script once, from the repository's root:

   ```bash
   julia setup.jl FooMessagePassingRules --owner ReactiveBayes --author "Your Name <you@example.com>"
   ```

   It renames the package, gives it a new UUID, points every link at your repository, resets the
   changelog and the licence's copyright, removes what only the template needs, and prints the
   steps left.
3. Run `make test` and `make docs`. Both pass before you change anything.

## What the package holds

```text
FooMessagePassingRules/
├── src/FooMessagePassingRules.jl   the nodes and their rules
├── test/
│   ├── runtests.jl                 runs the test items, then the rule-coverage gate
│   ├── quality_tests.jl            Aqua, the dependencies, the doctests, check_rules
│   └── rules/                      one file of test items per node
├── docs/src/index.md               one page per node
├── Makefile                        test, docs, format: as CI runs them
└── .github/workflows/              CI, a weekly run, documentation, formatting, CompatHelper, TagBot
```

The package depends on MessagePassingRulesBase and on the distribution packages its rules
return, and on no engine: an engine finds the rules because they are methods of
[`find_message_rule`](@ref) and its siblings. MessagePassingRulesTestUtils is a test dependency
only. `quality_tests.jl` checks both.

## Write the node and its rules

Declare each node with [`@define_factor_node`](@ref) and define its rules with
[`@define_message_update_rule`](@ref), [`@define_marginal_update_rule`](@ref) and
[`@define_average_energy`](@ref). Declare a node before its rules, since a rule that omits
`algorithm` takes its node's default. [Your first node](@ref tutorial-first-node) writes a node
like the template's example step by step; [Defining nodes](@ref) and [Defining rules](@ref) cover
every option.

## Test every rule

The tests use [MessagePassingRulesTestUtils](https://reactivebayes.github.io/MessagePassingRulesTestUtils.jl/stable/),
whose tutorial [Testing a rule package](https://reactivebayes.github.io/MessagePassingRulesTestUtils.jl/stable/tutorials/rule-package/)
uses the same node:

- a table of cases for every rule, `@test_message_update_rule`, `@test_marginal_update_rule` and
  `@test_average_energy`, each case with the result it must return;
- a message rule verified against the node's density, `@verify_message_update_rule`, which
  catches a derivation that is wrong in the rule and its table alike;
- derivatives, `@test_rule_derivatives`, for rules a model differentiates through.

`test/runtests.jl` ends with the rule-coverage gate: after a run of the whole suite, every rule
the package defines must have been selected by some test, or the suite fails and names the rule.
`quality_tests.jl` runs [`check_rules`](@ref) and [`check_rule_ambiguities`](@ref), which find a
rule that disagrees with its node's declaration and two rules that could match one call.

## Document the node

Each node has a page, in the same order on every site: overview, definition, interfaces,
algorithm, supported rules, example, limitations and API. The supported rules are
[`rule_coverage`](@ref)'s table, and the examples call the rules, as this site does, rather
than build a model. Every Julia block runs when the site is built, so the documentation cannot
drift from the code.

## Publish

CI tests the package on Julia 1.10 and later, measures coverage, checks the formatting with
Runic, and deploys the documentation: `dev` from `main`, a version from each tag, and a preview
for each pull request, deleted when the pull request closes. The setup script prints the three
steps that need you: a `DOCUMENTER_KEY` secret for the deployment, GitHub Pages from the
`gh-pages` branch, and registration, by commenting `@JuliaRegistrator register` on a commit.
TagBot then tags the release, and CompatHelper proposes new compat bounds as your dependencies
release. Once a week, `Weekly.yml` runs the suite on the latest Julia with the latest release of
every dependency, so a package that sees no commit still learns when a dependency breaks it.
