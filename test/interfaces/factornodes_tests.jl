@testitem "sdtype" begin
    using Distributions

    @test isdeterministic(Deterministic()) === true
    @test isdeterministic(Deterministic) === true
    @test isdeterministic(Stochastic()) === false
    @test isdeterministic(Stochastic) === false
    @test isstochastic(Deterministic()) === false
    @test isstochastic(Deterministic) === false
    @test isstochastic(Stochastic()) === true
    @test isstochastic(Stochastic) === true

    @test sdtype(() -> nothing) === Deterministic()
    @test sdtype(Normal(0.0, 1.0)) === Stochastic()

    @test_throws "Unknown if an object of type `Vector{Float64}` is stochastic or deterministic." sdtype([
        1.0, 2.0, 3.0
    ])
    @test_throws "Unknown if an object of type `Matrix{Float64}` is stochastic or deterministic." sdtype(
        [1.0 0.0; 0.0 1.0]
    )
    @test_throws "Unknown if an object of type `Int64` is stochastic or deterministic." sdtype(0)
end

@testitem "is_predefined_node" begin
    import MessagePassingRulesBase: is_predefined_node, PredefinedNodeFunctionalForm, UndefinedNodeFunctionalForm

    @test is_predefined_node(() -> nothing) === UndefinedNodeFunctionalForm()
    @test is_predefined_node(2) === UndefinedNodeFunctionalForm()

    struct ArbitraryFactorNodeForIsPredefinedTest end

    @node ArbitraryFactorNodeForIsPredefinedTest Stochastic [out, in]

    @test is_predefined_node(ArbitraryFactorNodeForIsPredefinedTest) === PredefinedNodeFunctionalForm()
end

@testitem "@node macro" begin
    import MessagePassingRulesBase: alias_interface

    struct CustomStochasticNode end

    @node CustomStochasticNode Stochastic [out, (x, aliases = [xx]), (y, aliases = [yy]), z]

    function customstochasticnode end

    @node typeof(customstochasticnode) Stochastic [out, (x, aliases = [xx]), (y, aliases = [yy]), z]

    struct CustomDeterministicNode end

    CustomDeterministicNode(x, y, z) = x + y + z

    @node CustomDeterministicNode Deterministic [out, (x, aliases = [xx]), (y, aliases = [yy]), z]

    function customdeterministicnode end

    customdeterministicnode(x, y, z) = x + y + z

    @node typeof(customdeterministicnode) Deterministic [out, (x, aliases = [xx]), (y, aliases = [yy]), z]

    @test MessagePassingRulesBase.sdtype(CustomStochasticNode) === Stochastic()
    @test MessagePassingRulesBase.sdtype(customstochasticnode) === Stochastic()
    @test MessagePassingRulesBase.sdtype(CustomDeterministicNode) === Deterministic()
    @test MessagePassingRulesBase.sdtype(customdeterministicnode) === Deterministic()

    for node in [CustomStochasticNode, customstochasticnode, CustomDeterministicNode, customdeterministicnode]
        @test alias_interface(node, 1, :out) === :out
        @test alias_interface(node, 2, :x) === :x
        @test alias_interface(node, 2, :xx) === :x
        @test alias_interface(node, 3, :y) === :y
        @test alias_interface(node, 3, :yy) === :y
        @test_throws ErrorException alias_interface(node, 4, :out) === :x
        @test_throws ErrorException alias_interface(node, 4, :x) === :x
        @test_throws ErrorException alias_interface(node, 4, :y) === :x
        @test_throws ErrorException alias_interface(node, 4, :zz)
    end

    struct DummyStruct end

    @test_throws Exception eval(:(@node DummyStruct NotStochasticAndNotDeterministic [out, in, x]))
    @test_throws Exception eval(:(@node DummyStruct Stochastic [1, in, x]))
    @test_throws Exception eval(:(@node DummyStruct Stochastic [p, in, x] aliases = [([z], y, x)]))
    @test_throws Exception eval(:(@node DummyStruct Stochastic [(out, aliases = [1]), in, x]))
    @test_throws Exception eval(:(@node DummyStruct Stochastic []))
end

@testitem "sdtype of an arbitrary distribution is Stochastic" begin
    using Distributions

    struct DummyDistribution <: Distribution{Univariate, Continuous} end

    @test sdtype(DummyDistribution) === Stochastic()
end

# This is a limitation of the current implementation, which can be removed in the future
@testitem "@node macro (in the current implementation) should not support interface names with underscores" begin
    @test_throws "Node interfaces names (and aliases) must not contain `_` symbol in them, found in `c_d`" eval(
        quote
            struct DummyNode end

            @node DummyNode Stochastic [out, c_d]
        end
    )
    @test_throws "Node interfaces names (and aliases) must not contain `_` symbol in them, found in `d_b_a`" eval(
        quote
            struct DummyNode end

            @node DummyNode Stochastic [out, c, d_b_a]
        end
    )
    @test_throws "Node interfaces names (and aliases) must not contain `_` symbol in them, found in `c_d`" eval(
        quote
            struct DummyNode end

            @node DummyNode Stochastic [out, (c, aliases = [c_d])]
        end
    )
end

@testitem "@node macro should generate a documentation entry for a newly specified node" begin
    using REPL # `REPL` changes the docstring output format

    struct DummyNodeForDocumentationStochastic end
    struct DummyNodeForDocumentationDeterministic end

    @node DummyNodeForDocumentationStochastic Stochastic [out, x, (y, aliases = [yy])]

    @node DummyNodeForDocumentationDeterministic Deterministic [out, (x, aliases = [xx, xxx]), y]

    binding = @doc(MessagePassingRulesBase.is_predefined_node)
    @test !isnothing(binding)

    documentation = string(binding)
    @test occursin(r"DummyNodeForDocumentationStochastic.*Stochastic.*out, x, y \(or yy\)", documentation)
    @test occursin(r"DummyNodeForDocumentationDeterministic.*Deterministic.*out, x \(or xx, xxx\), y", documentation)
end

@testitem "`@node` macro should generate the node function in all directions for `Stochastic` nodes" begin
    @testset "For a regular node a user needs to define a node function" begin
        struct DummyNodeForNodeFunction end

        @node DummyNodeForNodeFunction Stochastic [out, x, y, z]

        nodefunction = (out, x, y, z) -> out^4 + x^3 + y^2 + z

        MessagePassingRulesBase.nodefunction(::Type{DummyNodeForNodeFunction}) =
            (; out, x, y, z) -> nodefunction(out, x, y, z)

        for out in (-1, 1), x in (-1, 1), y in (-1, 1), z in (-1, 1)
            @test MessagePassingRulesBase.nodefunction(DummyNodeForNodeFunction, Val(:out), x = x, y = y, z = z)(out) ≈
                nodefunction(out, x, y, z)
            @test MessagePassingRulesBase.nodefunction(DummyNodeForNodeFunction, Val(:x), out = out, y = y, z = z)(x) ≈
                nodefunction(out, x, y, z)
            @test MessagePassingRulesBase.nodefunction(DummyNodeForNodeFunction, Val(:y), out = out, x = x, z = z)(y) ≈
                nodefunction(out, x, y, z)
            @test MessagePassingRulesBase.nodefunction(DummyNodeForNodeFunction, Val(:z), out = out, x = x, y = y)(z) ≈
                nodefunction(out, x, y, z)
        end
    end

    @testset "Distributions are the special case and they simple call the `logpdf` as their node function" begin
        using Distributions

        struct DummyNodeForNodeFunctionAsDistribution <: Distributions.ContinuousUnivariateDistribution
            mean
            var
        end

        @node DummyNodeForNodeFunctionAsDistribution Stochastic [out, mean, var]

        Distributions.logpdf(node::DummyNodeForNodeFunctionAsDistribution, out) =
            Distributions.logpdf(Distributions.Normal(node.mean, node.var), out)

        nodefunction = (out, mean, var) -> Distributions.logpdf(Distributions.Normal(mean, var), out)

        for out in (-1, 1), mean in (-1, 1), var in (1, 2)
            @test MessagePassingRulesBase.nodefunction(
                DummyNodeForNodeFunctionAsDistribution, Val(:out), mean = mean, var = var
            )(
                out
            ) ≈ nodefunction(out, mean, var)
            @test MessagePassingRulesBase.nodefunction(
                DummyNodeForNodeFunctionAsDistribution, Val(:mean), out = out, var = var
            )(
                mean
            ) ≈ nodefunction(out, mean, var)
            @test MessagePassingRulesBase.nodefunction(
                DummyNodeForNodeFunctionAsDistribution, Val(:var), out = out, mean = mean
            )(
                var
            ) ≈ nodefunction(out, mean, var)
        end
    end
end