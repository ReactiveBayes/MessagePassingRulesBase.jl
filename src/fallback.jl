"""
    NodeFunctionRuleFallback(extract = mean)
    (fallback::NodeFunctionRuleFallback)(node, target, args::RuleArgs)

A rule fallback: the message a stochastic node sends when no rule matches, computed from its
[`nodefunction`](@ref), the log-density its declaration defines. The message towards `out` or
another interface is the node's log-density in that interface, every other input, a message or
a marginal, collapsed to a point by `extract`. It is a [`NodeFunctionLogPdf`](@ref), unnormalised,
which a form constraint or a product with a proper distribution turns into one. Its log scale is
undefined.

# Arguments
- `extract`: the function collapsing each input to a point. Default: `mean`.

# Returns
Called as `fallback(node, target, args)`: a [`NodeFunctionLogPdf`](@ref), or `nothing` where the
node function does not apply: a deterministic node, a node with groups, a member of a group, an
input that is a joint, or an interface other than the target that has no input.

An engine consults a fallback only when resolution finds no rule, so an error inside a rule is
never turned into a fallback; ReactiveMP takes it as the activation option `rulefallback`. A
fallback of one's own is any callable of `(node, target, args)` returning a message or `nothing`.

# Examples

```julia
fallback = NodeFunctionRuleFallback()
message = fallback(NormalMeanVariance, MessagePassingRulesBase.Target(:out),
                   MessagePassingRulesBase.RuleArgs(m = (μ = PointMass(0.0), v = PointMass(1.0))))
logpdf(message, 0.5)   # logpdf(NormalMeanVariance(0.0, 1.0), 0.5)
```
"""
struct NodeFunctionRuleFallback{E}
    extract::E
end

NodeFunctionRuleFallback() = NodeFunctionRuleFallback(mean)

"""
    NodeFunctionLogPdf(logpdf)

The message a [`NodeFunctionRuleFallback`](@ref) computes: an unnormalised log-density, supported
everywhere. `BayesBase.logpdf(d, x)` and `d(x)` are both `logpdf(x)`, and `insupport(d, x)` is
always `true`.
"""
struct NodeFunctionLogPdf{F}
    logpdf::F
end

BayesBase.logpdf(d::NodeFunctionLogPdf, x) = d.logpdf(x)
BayesBase.insupport(::NodeFunctionLogPdf, x) = true
(d::NodeFunctionLogPdf)(x) = logpdf(d, x)
Base.show(io::IO, ::NodeFunctionLogPdf) = print(io, "NodeFunctionLogPdf(the node's log-density, other inputs fixed)")

(fallback::NodeFunctionRuleFallback)(node, target, args) = nothing

function (fallback::NodeFunctionRuleFallback)(node, ::Target{E}, args::RuleArgs) where {E}
    applicable(nodefunction, node) || return nothing
    inputs = (rule_inputs(node, args.m)..., rule_inputs(node, args.q)...)
    all(((key, _),) -> key isa Symbol, inputs) || return nothing
    # The log-density needs a value for every interface but the target.
    issetequal(map(first, inputs), Iterators.filter(!=(E), interfaces(node))) || return nothing
    points = NamedTuple{map(first, inputs)}(map(((_, value),) -> fallback.extract(value), inputs))
    f = nodefunction(node)
    # The target's keyword as a `NamedTuple` whose names are known at compile time: splatting the
    # pair `E => x` would build its type at run time on every evaluation.
    return NodeFunctionLogPdf(x -> f(; points..., NamedTuple{(E,)}((x,))...))
end

"""
    call_fallback(fallback, node, target, algorithm, ctx, args)

How an engine consults a rule fallback when resolution finds no rule for a message or a marginal:
with the node, the target, the node's algorithm, the [`RuleContext`](@ref) its rules receive and
the arguments. The default asks a three-argument fallback, `fallback(node, target, args)`, about
messages only (`Target`, `IndexedTarget`), and answers `nothing` for a marginal
(`ClusterTarget`): a fallback written for messages is never asked about anything else. A fallback
that wants the algorithm or the context, such as the node instance `ctx.node` or the expectation
backend `ctx.expectation`, adds a method of its own for its type, leaving the target untyped or
typing it: `call_fallback(::MyFallback, node, target, algorithm, ctx, args)`.

A fallback that knows the log scale of its message returns
[`with_logscale`](@ref)`(message, logscale)`, which the engine takes apart with
[`unwrap_fallback`](@ref); any other message has an undefined log scale.

See also [`call_energy_fallback`](@ref), [`NodeFunctionRuleFallback`](@ref).
"""
call_fallback(fallback, node, target, algorithm, ctx, args) = three_argument_fallback(fallback, node, target, args)

"""
    unwrap_fallback(answer) -> (result, logscale)

What an engine does with a fallback's answer: the result and its log scale. A fallback that knows
its message's log scale returns [`with_logscale`](@ref)`(message, logscale)`, a number or an
[`UndefinedLogScale`](@ref) with its reason, such as `:unnormalised_product` for an unnormalised
density whose normaliser a form constraint computes; any other answer has the log scale
`UndefinedLogScale(:fallback)`.
"""
unwrap_fallback(answer::WithLogScale) = (answer.result, answer.logscale)
unwrap_fallback(answer) = (answer, UndefinedLogScale(:fallback))

# One untyped default, so that a fallback's own method, `call_fallback(::MyFallback, node, target,
# algorithm, ctx, args)`, is more specific than it for every target
three_argument_fallback(fallback, node, target::Union{Target, IndexedTarget}, args) = fallback(node, target, args)
three_argument_fallback(fallback, node, target::ClusterTarget, args) = nothing

"""
    call_energy_fallback(fallback, node, algorithm, ctx, args)

How an engine consults a rule fallback when no average energy is defined for a node, a term of
the free energy: `nothing` by default, so that a fallback written for messages leaves the free
energy as it was. See [`call_fallback`](@ref).
"""
call_energy_fallback(fallback, node, algorithm, ctx, args) = nothing

# With the full signature, `NodeFunctionRuleFallback` also serves deterministic nodes, through the
# node instance in the context, and nodes with groups; its messages stay plug-in.
function call_fallback(fallback::NodeFunctionRuleFallback, node, target::Union{Target, IndexedTarget}, algorithm, ctx, args)
    sdtype(node) isa Deterministic && return deterministic_message(fallback, node, target, ctx, args)
    isempty(interface_groups(node)) && return fallback(node, target, args)
    return grouped_message(fallback, node, target, args)
end

# The average energy -E_q[log f] of a stochastic node, through the context's expectation backend,
# when every interface has a marginal of its own (a mean-field cluster)
function call_energy_fallback(fallback::NodeFunctionRuleFallback, node, algorithm, ctx, args)
    backend = ctx.expectation
    (isnothing(backend) || !(sdtype(node) isa Stochastic) || !applicable(nodefunction, node)) && return nothing
    inputs = rule_inputs(node, args.q)
    all(((key, _),) -> key isa Symbol, inputs) || return nothing
    issetequal(map(first, inputs), interfaces(node)) || return nothing
    names = map(first, inputs)
    f = nodefunction(node)
    joint = BayesBase.FactorizedJoint(map(last, inputs))
    return -BayesBase.expectation(backend, values -> f(; NamedTuple{names}(values)...), joint)
end

# A deterministic node's messages, through its function `getnodefn(ctx.node, Target(:out))` of the
# inputs in order: towards an input, the message on `out` pulled back through the function, the
# other inputs plugged in; towards `out`, the function at the plugged-in inputs
function deterministic_message(fallback, node, target, ctx, args)
    instance = ctx.node
    isnothing(instance) && return nothing
    f = getnodefn(instance, Target(:out))
    inputs = (rule_inputs(node, args.m)..., rule_inputs(node, args.q)...)
    values = Dict(inputs)
    order = input_order(node, inputs, target)
    isnothing(order) && return nothing
    if target isa Target{:out}
        return PointMass(f(map(key -> fallback.extract(values[key]), order)...))
    end
    haskey(values, :out) || return nothing
    outbound = values[:out]
    position = findfirst(==(target_key(target)), order)
    points = map(key -> key == target_key(target) ? nothing : fallback.extract(values[key]), order)
    return NodeFunctionLogPdf(x -> logpdf(outbound, f(Base.setindex(points, x, position)...)))
end

# The inputs of a deterministic node in its function's order, the target among them: the
# interfaces after `out`, a group by its members' indices
function input_order(node, inputs, target)
    keys = (map(first, inputs)..., target_key(target))
    order = Any[]
    for name in Iterators.drop(interfaces(node), 1)
        if name in interface_groups(node)
            members = sort!([key[2] for key in keys if key isa Tuple{Symbol, Integer} && key[1] === name])
            append!(order, [(name, k) for k in members])
        else
            name in keys || return nothing
            push!(order, name)
        end
    end
    return Tuple(order)
end

target_key(::Target{E}) where {E} = E
target_key(target::IndexedTarget{E}) where {E} = (E, target.index)

# A stochastic node with groups: every interface but the target collapsed to a point, a group to a
# tuple of points, and the target, or the target's member of its group, left free
function grouped_message(fallback, node, target, args)
    applicable(nodefunction, node) || return nothing
    inputs = (rule_inputs(node, args.m)..., rule_inputs(node, args.q)...)
    singles = Dict{Symbol, Any}()
    members = Dict{Symbol, Dict{Int, Any}}()
    for (key, value) in inputs
        if key isa Symbol
            singles[key] = fallback.extract(value)
        elseif key isa Tuple{Symbol, Integer}
            get!(members, key[1], Dict{Int, Any}())[key[2]] = fallback.extract(value)
        else
            return nothing # a joint
        end
    end
    E = target isa IndexedTarget ? target_key(target)[1] : target_key(target)
    names = Tuple(filter(!=(E), interfaces(node)))
    points = map(names) do name
        name in interface_groups(node) || return singles[name]
        group = members[name]
        return Tuple(group[k] for k in 1:length(group))
    end
    fixed = NamedTuple{names}(points)
    f = nodefunction(node)
    target isa Target && return NodeFunctionLogPdf(x -> f(; fixed..., NamedTuple{(E,)}((x,))...))
    k = target.index
    group = get(members, E, Dict{Int, Any}())
    n = max(k, maximum(keys(group); init = 0))
    return NodeFunctionLogPdf(x -> f(; fixed..., NamedTuple{(E,)}((ntuple(j -> j == k ? x : group[j], n),))...))
end
