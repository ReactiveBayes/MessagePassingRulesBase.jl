@testmodule InplaceRules begin
    using MessagePassingRulesBase
    using MessagePassingRulesBase: buffer_like
    using LinearAlgebra: mul!

    struct Affine end
    @define_factor_node(node = Affine, type = Deterministic, interfaces = [:out, :A, :x])
    @define_message_update_rule(
        node = Affine,
        target = :out,
        inplace = true,
        args = (m[:A]::Matrix{Float64}, m[:x]::Vector{Float64}),
        preallocate = (args) -> buffer_like(args.m[:x]),
        body = (output::Vector{Float64}, args) -> mul!(output, args.m[:A], args.m[:x]),
    )

    # An in-place joint marginal, and one with no in-place form.
    @define_marginal_update_rule(
        node = Affine, target = (:out, :x), inplace = true,
        args = (m[:out]::Vector{Float64}, m[:x]::Vector{Float64}),
        preallocate = (args) -> zeros(length(args.m[:out]) + length(args.m[:x])),
        body = (output::Vector{Float64}, args) -> (output .= [args.m[:out]; args.m[:x]]; output),
    )
    @define_marginal_update_rule(
        node = Affine, target = (:A, :x), args = (m[:A]::Matrix{Float64}, m[:x]::Vector{Float64}),
        body = (args) -> (args.m[:A], args.m[:x]),
    )

    using MessagePassingRulesBase: RuleArgs, Target, DefaultAlgorithm
    const ARGS = RuleArgs(m = (A = [1.0 2.0; 3.0 4.0], x = [1.0, 1.0]))
    const BUFFER = zeros(2)
    into_buffer() = getresult(message_passing_rule!(BUFFER, Affine, Target(:out), DefaultAlgorithm(), ARGS))
    allocating() = getresult(message_passing_rule(Affine, Target(:out), DefaultAlgorithm(), ARGS))
    measure(f) = (f(); @allocated f())
end

@testitem "inplace:agreement" tags = [:base] setup = [InplaceRules] begin
    I = InplaceRules
    @test I.allocating() == [3.0, 7.0]
    @test I.into_buffer() === I.BUFFER
    @test I.BUFFER == I.allocating()
end

@testitem "inplace:allocations" tags = [:base, :alloc] setup = [InplaceRules] begin
    # In-place with a provided buffer allocates nothing; the allocating form pays for its
    # buffer, which is the negative control.
    I = InplaceRules
    @test I.measure(I.into_buffer) == 0
    @test I.measure(I.allocating) > 0
end

@testitem "inplace:buffer_like" tags = [:base] begin
    using MessagePassingRulesBase: buffer_like
    v = [1.0, 2.0]
    b = buffer_like(v)
    @test b isa Vector{Float64} && size(b) == size(v) && b !== v
    @test buffer_like(v, Float32) isa Vector{Float32}
    m = buffer_like([1 2; 3 4])
    @test m isa Matrix{Int} && size(m) == (2, 2)
    nested = buffer_like((a = [1.0], b = ([2.0, 3.0],)))
    @test nested.a isa Vector{Float64} && nested.b[1] isa Vector{Float64} && length(nested.b[1]) == 2
    @test_throws ArgumentError buffer_like(1.0)
end

@testitem "inplace:marginal" tags = [:base] setup = [InplaceRules] begin
    using MessagePassingRulesBase: message_passing_marginalrule!, ClusterTarget, RuleArgs, DefaultAlgorithm
    I = InplaceRules
    buffer = zeros(4)
    result = message_passing_marginalrule!(buffer, I.Affine, ClusterTarget((:out, :x)), DefaultAlgorithm(), RuleArgs(m = (out = [1.0, 2.0], x = [3.0, 4.0])))
    @test getresult(result) === buffer && buffer == [1.0, 2.0, 3.0, 4.0]
    # A marginal rule with no in-place form refuses a buffer.
    args = RuleArgs(m = (A = [1.0 0.0; 0.0 1.0], x = [1.0, 1.0]))
    err = try
        message_passing_marginalrule!(zeros(2), I.Affine, ClusterTarget((:A, :x)), DefaultAlgorithm(), args)
    catch e
        e
    end
    @test err isa ArgumentError && contains(err.msg, "has no in-place form")
end
