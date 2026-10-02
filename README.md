# MessagePassingRulesBase

[![CI](https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ReactiveBayes/MessagePassingRulesBase.jl/actions/workflows/CI.yml)
[![Docs: stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://reactivebayes.github.io/MessagePassingRulesBase.jl/stable/)
[![Docs: dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://reactivebayes.github.io/MessagePassingRulesBase.jl/dev/)
[![Coverage](https://codecov.io/gh/ReactiveBayes/MessagePassingRulesBase.jl/graph/badge.svg)](https://codecov.io/gh/ReactiveBayes/MessagePassingRulesBase.jl)
[![Code style: Runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)

The rule system of the ReactiveMP ecosystem: the macros that declare factor nodes, their message
update rules, marginal rules, average energies and dependencies, and the lookup an engine uses to
find and run a rule for a node, a target and the types of its inputs. Rules are ordinary Julia
functions, found through dispatch whichever loaded package defines them, and callable and
testable without an engine. It also holds the math helpers the rule packages share, linear and
Gaussian algebra such as `add_outer` and `gaussian_second_moment`, public and documented. The
ReactiveMP ecosystem's rule packages build on it, and
[ReactiveMP](https://github.com/ReactiveBayes/ReactiveMP.jl) runs its rules.

```julia
import Pkg; Pkg.add("MessagePassingRulesBase")
```

```julia
using MessagePassingRulesBase

struct Shift end   # out = in + 1

@define_factor_node(node = Shift, type = Deterministic, interfaces = [:out, :in])

@define_message_update_rule(
    node = Shift, target = :out, args = (m[:in]::Real,), logscale = 0,
    body = (args) -> args.m[:in] + 1,
)

result = @call_message_update_rule(node = Shift, target = :out, m = (in = 1.0,))
getresult(result), getlogscale(result)   # (2.0, 0)
```

- Documentation: <https://reactivebayes.github.io/MessagePassingRulesBase.jl/stable/>. Build it
  locally with `julia --project=docs -e 'import Pkg; Pkg.instantiate()'` and then
  `julia --project=docs docs/make.jl`, into `docs/build`.
- Tests: `julia --project -e 'import Pkg; Pkg.test()'`; with `TEST_ALL=true` in the environment
  they include the items tagged `:slow`, and `Pkg.test(test_args = ["tag:alloc"])` selects by tag,
  `name:<text>` by name and a path by file.
- Depends on BayesBase, MacroTools, Compat, FastCholesky, IrrationalConstants and LinearAlgebra:
  no distribution package and no engine.
  Julia 1.10 or later. MIT licence.
