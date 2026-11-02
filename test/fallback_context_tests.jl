@testmodule ContextFallbackNodes begin
    using MessagePassingRulesBase, BayesBase

    # `out ~ Toy(a, b)`: a Gaussian in `out` with mean `a` and variance `b`, with no rules
    struct Toy{A, B}
        a::A
        b::B
    end
    BayesBase.logpdf(d::Toy, x) = -(x - d.a)^2 / (2 * d.b)
    @define_factor_node(node = Toy, type = Stochastic, interfaces = [:out, :a, :b])

    # `out ~ Mix(z, means...)`: a Gaussian with unit variance around the `z`-th mean
    struct Mix{Z, M}
        z::Z
        means::M
    end
    BayesBase.logpdf(d::Mix, x) = -(x - d.means[d.z])^2 / 2
    @define_factor_node(node = Mix, type = Stochastic, interfaces = [:out, :z, :means...])
    # a node with groups has no generated node function; it opts in to the fallback by defining one
    MessagePassingRulesBase.nodefunction(::Type{<:Mix}) = (; out, z, means) -> logpdf(Mix(z, means), out)

    # `out = f(in...)`, a deterministic node whose function an engine's node instance holds
    struct Func end
    @define_factor_node(node = Func, type = Deterministic, interfaces = [:out, :in...])
    struct FuncNode{F}
        f::F
    end
    MessagePassingRulesBase.getnodefn(node::FuncNode, ::MessagePassingRulesBase.Target{:out}) = node.f

    # An expectation backend: three-point Gauss–Hermite for a Normal, exact for a point mass, so
    # quadratic integrands are exact
    struct TestNormal
        m::Float64
        v::Float64
    end
    struct ThreePoints end
    BayesBase.supports(::ThreePoints, ::Type, ::Type{<:Union{TestNormal, PointMass}}) = true
    function BayesBase.prepare_expectation(::ThreePoints, q::TestNormal)
        s = sqrt(3 * q.v)
        return BayesBase.PointSet((q.m - s, q.m, q.m + s), (1 / 6, 2 / 3, 1 / 6))
    end
    BayesBase.prepare_expectation(::ThreePoints, q::PointMass) = BayesBase.PointSet((mean(q),), (1.0,))
end

@testitem "call_fallback: a three-argument fallback answers messages only" tags = [:base] setup = [ContextFallbackNodes] begin
    using MessagePassingRulesBase, BayesBase
    using MessagePassingRulesBase: RuleArgs, RuleContext, Target, IndexedTarget, ClusterTarget, call_fallback, call_energy_fallback
    N = ContextFallbackNodes
    calls = Ref(0)
    fallback(node, target, args) = (calls[] += 1; :answered)
    args = RuleArgs(m = (a = PointMass(1.0),))
    @test call_fallback(fallback, N.Toy, Target(:out), nothing, RuleContext(), args) === :answered
    @test call_fallback(fallback, N.Toy, IndexedTarget(:x, 1), nothing, RuleContext(), args) === :answered
    # a marginal or an average energy is not a question it was written for
    @test call_fallback(fallback, N.Toy, ClusterTarget((:out, :a)), nothing, RuleContext(), args) === nothing
    @test call_energy_fallback(fallback, N.Toy, nothing, RuleContext(), args) === nothing
    @test calls[] == 2
end

@testitem "NodeFunctionRuleFallback: the full signature agrees with the three-argument one" tags = [:base] setup = [ContextFallbackNodes] begin
    using MessagePassingRulesBase, BayesBase
    using MessagePassingRulesBase: RuleArgs, RuleContext, Target, call_fallback
    N = ContextFallbackNodes
    fallback = NodeFunctionRuleFallback()
    args = RuleArgs(m = (a = PointMass(1.0),), q = (b = PointMass(2.0),))
    message = call_fallback(fallback, N.Toy, Target(:out), nothing, RuleContext(), args)
    @test logpdf(message, 3.0) == logpdf(fallback(N.Toy, Target(:out), args), 3.0)
end

@testitem "NodeFunctionRuleFallback: a deterministic node, through its node instance" tags = [:base] setup = [ContextFallbackNodes] begin
    using MessagePassingRulesBase, BayesBase
    using MessagePassingRulesBase: RuleArgs, RuleContext, Target, IndexedTarget, call_fallback
    N = ContextFallbackNodes
    fallback = NodeFunctionRuleFallback()
    ctx = RuleContext(node = N.FuncNode((x, y) -> x * y))
    # towards an input: the message on `out` pulled back through the function, the other input plugged in
    m_out = N.Toy(6.0, 1.0) # a log-density in `out`: -(out - 6)² / 2
    args = RuleArgs(m = (out = m_out, in = (nothing, PointMass(2.0))))
    message = call_fallback(fallback, N.Func, IndexedTarget(:in, 1), nothing, ctx, args)
    @test logpdf(message, 3.0) == logpdf(m_out, 3.0 * 2.0)
    @test logpdf(message, 1.0) == logpdf(m_out, 1.0 * 2.0)
    # towards `out`: the function at the plugged-in inputs
    forward = call_fallback(fallback, N.Func, Target(:out), nothing, ctx, RuleArgs(m = (in = (PointMass(3.0), PointMass(2.0)),)))
    @test forward == PointMass(6.0)
    # without a node instance there is no function to reach
    @test call_fallback(fallback, N.Func, Target(:out), nothing, RuleContext(), RuleArgs(m = (in = (PointMass(3.0), PointMass(2.0)),))) === nothing
end

@testitem "NodeFunctionRuleFallback: a member of a group" tags = [:base] setup = [ContextFallbackNodes] begin
    using MessagePassingRulesBase, BayesBase
    using MessagePassingRulesBase: RuleArgs, RuleContext, IndexedTarget, Target, call_fallback
    N = ContextFallbackNodes
    fallback = NodeFunctionRuleFallback()
    # towards the second mean, the first one and the selector plugged in
    args = RuleArgs(m = (out = PointMass(1.5), z = PointMass(2), means = (PointMass(-1.0), nothing)))
    message = call_fallback(fallback, N.Mix, IndexedTarget(:means, 2), nothing, RuleContext(), args)
    @test logpdf(message, 1.0) == logpdf(N.Mix(2, (-1.0, 1.0)), 1.5)
    # towards `out`, the whole group plugged in
    towards_out = call_fallback(fallback, N.Mix, Target(:out), nothing, RuleContext(), RuleArgs(m = (z = PointMass(1), means = (PointMass(-1.0), PointMass(1.0)))))
    @test logpdf(towards_out, 0.0) == logpdf(N.Mix(1, (-1.0, 1.0)), 0.0)
end

@testitem "NodeFunctionRuleFallback: the average energy through ctx.expectation" tags = [:base] setup = [ContextFallbackNodes] begin
    using MessagePassingRulesBase, BayesBase
    using MessagePassingRulesBase: RuleArgs, RuleContext, call_energy_fallback
    N = ContextFallbackNodes
    fallback = NodeFunctionRuleFallback()
    # -E[log Toy(a, b)(out)] with out ~ N(m, v) and point masses a, b: ((m - a)² + v) / (2b)
    args = RuleArgs(q = (out = N.TestNormal(1.0, 0.5), a = PointMass(0.25), b = PointMass(2.0)))
    energy = call_energy_fallback(fallback, N.Toy, nothing, RuleContext(expectation = N.ThreePoints()), args)
    @test energy ≈ ((1.0 - 0.25)^2 + 0.5) / (2 * 2.0)
    # no backend, or a joint marginal: no energy
    @test call_energy_fallback(fallback, N.Toy, nothing, RuleContext(), args) === nothing
end

@testitem "context: expectation is a default service" tags = [:base] begin
    using MessagePassingRulesBase
    @test :expectation in MessagePassingRulesBase.DEFAULT_CONTEXT_SERVICES
    @test MessagePassingRulesBase.RuleContext().expectation === nothing
end
