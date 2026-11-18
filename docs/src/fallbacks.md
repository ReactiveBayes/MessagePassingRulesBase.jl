```@meta
CurrentModule = MessagePassingRulesBase
```

# Rule fallbacks

Where no [rule](@ref glossary-rule) fits, an engine may consult a **rule fallback** instead of
reporting the error. A rule fallback is a callable, `fallback(node, target, args)`, that takes
the node, the target and the rule's arguments. It returns a [message](@ref glossary-message), or
`nothing` when it has none either.

An engine consults the fallback only when [resolution](@ref glossary-resolution) returns a [`RuleNotFound`](@ref). A fallback
therefore never replaces a rule that exists, and an error inside a rule is never turned into a
fallback. ReactiveMP takes a fallback as its activation option `rulefallback`. A message that a
fallback computes has an undefined [log scale](@ref glossary-log-scale) unless the fallback
returns [`with_logscale`](@ref)`(message, logscale)`. A fallback can also report how it computed
its answer by returning [`with_outcome`](@ref MessagePassingRulesBase.with_outcome)`(answer, outcome)`.
The engine passes the outcome on to its events, where an inference report can read it.

## The node function fallback

[`NodeFunctionRuleFallback`](@ref) is the fallback this package provides. Called with three
arguments, it applies to a [stochastic node](@ref glossary-stochastic-node) without groups. An
engine calls it with more information and gets messages for more kinds of nodes, see
[What an engine passes to a fallback](@ref). Its message towards a target is
the node's log-density as a function of the target, with every other input collapsed to a point,
by default its mean. The message is a [`NodeFunctionLogPdf`](@ref), an unnormalised
log-density. A form constraint, or a product with a proper distribution, turns it into a
distribution.

The node below is a normal distribution given by a function of its mean and variance. It has no
rules at all:

```@example fallbacks
using MessagePassingRulesBase, BayesBase, ExponentialFamily

gaussian(μ, v) = NormalMeanVariance(μ, v)   # the distribution of out, given μ and v

@define_factor_node(node = gaussian, type = Stochastic, interfaces = [:out, :μ, :v])

fallback = NodeFunctionRuleFallback()
args = MessagePassingRulesBase.RuleArgs(m = (out = PointMass(2.0),), q = (v = PointMass(0.5),))
message = fallback(gaussian, MessagePassingRulesBase.Target(:μ), args)

logpdf(message, 1.0), logpdf(NormalMeanVariance(1.0, 0.5), 2.0)
```

The fallback's message towards `μ` evaluates the node's log-density, ``\log \mathcal{N}(2 \mid
\mu, 0.5)``, at ``\mu = 1``. The observation `out = 2` and the variance `v = 0.5` were collapsed
to their means. An input that is not a point mass is collapsed the same way:

```@example fallbacks
args = MessagePassingRulesBase.RuleArgs(m = (out = NormalMeanVariance(2.0, 3.0),), q = (v = PointMass(0.5),))
logpdf(fallback(gaussian, MessagePassingRulesBase.Target(:μ), args), 1.0)
```

The message on `out` has the mean `2.0`, so the result is the same. Its variance is lost.

## Where the fallback has nothing

Called with three arguments, the fallback returns `nothing` for a deterministic node, a node
with groups, a member of a group, or an input that is a joint marginal. A [deterministic node](@ref glossary-deterministic-node)
has no log-density:

```jldoctest fallbacks
julia> using MessagePassingRulesBase

julia> struct Plain end

julia> @define_factor_node(node = Plain, type = Deterministic, interfaces = [:out, :in])

julia> NodeFunctionRuleFallback()(Plain, MessagePassingRulesBase.Target(:out), MessagePassingRulesBase.RuleArgs(m = (in = 1.0,))) === nothing
true
```

## What an engine passes to a fallback

An engine does not call a fallback directly. It calls
[`call_fallback`](@ref MessagePassingRulesBase.call_fallback) for a message or a marginal, and
[`call_energy_fallback`](@ref MessagePassingRulesBase.call_energy_fallback) for an average
energy. Both also receive the node's algorithm and the [`RuleContext`](@ref) that the node's
rules receive. By default, `call_fallback` calls a three-argument fallback for a message and
returns `nothing` for a marginal, and `call_energy_fallback` returns `nothing`.

`NodeFunctionRuleFallback` has its own methods of both, which use the context to cover more
cases:

- A deterministic node, through its function `getnodefn(ctx.node, Target(:out))`. The message
  towards an input is the message on `out` pulled back through the function, with the other
  inputs collapsed to points. The message towards `out` is a point mass at the function's value
  at those points.
- A stochastic node with groups, including the members of a group, when the node defines a node
  function.
- The average energy `-E_q[log f]` of a stochastic node whose interfaces each have their own
  marginal. The expectation backend `ctx.expectation` computes it; when the engine supplies no
  backend, the average energy is `nothing`.

```@docs
NodeFunctionRuleFallback
MessagePassingRulesBase.NodeFunctionLogPdf
```

```@docs
MessagePassingRulesBase.call_fallback
MessagePassingRulesBase.call_energy_fallback
MessagePassingRulesBase.unwrap_fallback
MessagePassingRulesBase.with_outcome
MessagePassingRulesBase.unwrap_outcome
MessagePassingRulesBase.WithOutcome
```
