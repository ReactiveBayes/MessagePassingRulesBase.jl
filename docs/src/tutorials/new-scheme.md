```@meta
CurrentModule = MessagePassingRulesBase
```

# [A new message passing scheme](@id tutorial-new-scheme)

A message passing scheme decides two things for each rule: which inputs it reads, and how it
turns them into a message. [Belief propagation](@ref glossary-belief-propagation),
[variational message passing](@ref glossary-vmp) and
[expectation propagation](@ref glossary-expectation-propagation) answer them differently. A new
scheme needs no new machinery here. It is an [algorithm](@ref glossary-algorithm), a declaration
of what its rules read, and the rules themselves, written with the same macros as any other.

This tutorial writes one: natural-gradient message passing, after Lukashchuk, Yemets, Ledbetter
and Şenöz, [*Information Geometry of Message Passing*](https://arxiv.org/abs/2608.15922) (2026).
It assumes you have read [A node with its own algorithm](@ref tutorial-algorithm).

## The scheme

Take a count observed through a log rate, ``y \sim \operatorname{Poisson}(e^x)``, with a normal
belief ``q(x) = \mathcal{N}(m, v)``. The log factor is

```math
\log f(y, x) = y x - e^x - \log y!.
```

Its exact message towards ``x``, ``x \mapsto f(y, x)``, is not normal. A variational message,
``\exp \mathbb{E}_q[\log f]``, averages the factor under the belief instead. A natural-gradient
message keeps the part of the factor that a normal belief can represent: the normal whose
precision is the expected curvature of ``\log f`` under ``q``, and whose weighted mean follows
the expected slope,

```math
w = -\mathbb{E}_q\big[\partial_x^2 \log f\big] = \mathbb{E}_q[e^x] = e^{m + v/2}, \qquad
\xi = \mathbb{E}_q\big[\partial_x \log f\big] + w\, m = y - e^{m + v/2} + w\, m.
```

Both expectations are in closed form, since ``\mathbb{E}_q[e^x]`` is the mean of a log-normal. The
message reads the belief ``q(x)`` on its own edge, which neither belief propagation nor the
default scheme gives a rule.

## The algorithm and what it reads

The scheme is an algorithm, a type with no fields here:

```@example new-scheme
using MessagePassingRulesBase, BayesBase, ExponentialFamily

struct NaturalGradient <: AbstractAlgorithm end

struct PoissonLog end   # out ~ Poisson(exp(in))

@define_factor_node(node = PoissonLog, type = Stochastic, interfaces = [:out, :in])
nothing # hide
```

Its rule towards `in` reads the observation and the belief on `in` itself, so the node declares
that for the algorithm, with [`@define_dependencies`](@ref). The target `out` follows the default
scheme:

```@example new-scheme
@define_dependencies(
    node = PoissonLog, algorithm = NaturalGradient,
    dependencies = [:out => (default,), :in => (q[:out], q[:in])],
)

MessagePassingRulesBase.dependencies_spec(PoissonLog, NaturalGradient())
```

## The rule

The rule is the two formulas above, under the algorithm:

```@example new-scheme
@define_message_update_rule(
    node = PoissonLog, target = :in, algorithm = NaturalGradient,
    args = (q[:out]::PointMass, q[:in]::UnivariateNormalDistributionsFamily),
    body = (args) -> begin
        y = mean(args.q[:out])
        m, v = mean_var(args.q[:in])
        w = exp(m + v / 2)   # E_q[e^x]
        NormalWeightedMeanPrecision(y - w + w * m, w)
    end,
)

@call_message_update_rule(
    node = PoissonLog, target = :in, algorithm = NaturalGradient(),
    q = (out = PointMass(3), in = NormalMeanVariance(0.0, 1.0)),
)
```

## Iterating to a fixed point

The message depends on the belief it updates, so the two are iterated: the belief is the prior
times the message, and the message is recomputed from the new belief. With a standard normal
prior and the count ``y = 3``:

```@example new-scheme
prior = NormalMeanVariance(0.0, 1.0)
belief = prior
for iteration in 1:20
    message = getresult(@call_message_update_rule(
        node = PoissonLog, target = :in, algorithm = NaturalGradient(),
        q = (out = PointMass(3), in = belief),
    ))
    global belief = prod(ClosedProd(), prior, message)
end
mean_var(belief)
```

The belief settles where the scheme is stationary: its precision is the prior's plus
``e^{m + v/2}``, and its mean is ``y - e^{m + v/2}`` for this prior. That is the condition for the
best normal approximation of the posterior in the variational sense:

```@example new-scheme
m, v = mean_var(belief)
(precision = 1 / v - (1 + exp(m + v / 2)), mean = m - (3 - exp(m + v / 2)))
```

An engine does the same iteration on a whole graph, running each rule whenever the inputs it
declared change. Nothing in the rule refers to the engine: a scheme is the algorithm, what its
rules read, and what they compute.
