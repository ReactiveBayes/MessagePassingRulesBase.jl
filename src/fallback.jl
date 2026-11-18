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
input that is a joint, or an interface other than the target that has no input. Through
[`call_fallback`](@ref), which an engine calls with the node's rule context, it also computes
messages for a deterministic node, from the node instance's function, and for a node with
groups. Through [`call_energy_fallback`](@ref) it computes the average energy `-E_q[log f]` of a
mean-field cluster.

An engine consults a fallback only when resolution finds no rule, so an error inside a rule is
never turned into a fallback; ReactiveMP takes it as the activation option `rulefallback`. A
user-defined fallback is any callable of `(node, target, args)` that returns a message or
`nothing`. A fallback type can instead define a method of [`call_fallback`](@ref), which also
receives the node's algorithm and rule context and can answer for marginals, and a method of
[`call_energy_fallback`](@ref) to answer for average energies.

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

A message given by an unnormalised log-density, supported everywhere.
[`NodeFunctionRuleFallback`](@ref) returns its messages in this form, and other rule fallbacks
can use it too, for example for a log-density pulled back through a deterministic function or
averaged over other inputs.
`BayesBase.logpdf(d, x)` and `d(x)` are both `logpdf(x)`, and `insupport(d, x)` is always `true`.
"""
struct NodeFunctionLogPdf{F}
    logpdf::F
end

BayesBase.logpdf(d::NodeFunctionLogPdf, x) = d.logpdf(x)
BayesBase.insupport(::NodeFunctionLogPdf, x) = true
(d::NodeFunctionLogPdf)(x) = logpdf(d, x)
Base.show(io::IO, ::NodeFunctionLogPdf) = print(io, "NodeFunctionLogPdf(an unnormalised log-density)")

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

Consult the rule `fallback` for a message or a marginal that has no rule. An engine calls this
when resolution finds no rule, with the node, the target, the node's algorithm, the
[`RuleContext`](@ref) that the node's rules receive, and the rule's arguments.

The default method calls a three-argument fallback, `fallback(node, target, args)`, for a
message (a `Target` or an `IndexedTarget`) and returns `nothing` for a marginal (a
`ClusterTarget`), so a fallback written for messages is only asked for messages. A fallback that
needs the algorithm or the context, for example the node instance `ctx.node` or the expectation
backend `ctx.expectation`, defines a method for its type,
`call_fallback(::MyFallback, node, target, algorithm, ctx, args)`, with `target` untyped or
restricted to the targets it handles.

A fallback that knows the log scale of its message returns
[`with_logscale`](@ref)`(message, logscale)`, and the engine separates the two with
[`unwrap_fallback`](@ref). Any other message has an undefined log scale.

See also [`call_energy_fallback`](@ref), [`NodeFunctionRuleFallback`](@ref).
"""
call_fallback(fallback, node, target, algorithm, ctx, args) = three_argument_fallback(fallback, node, target, args)

"""
    unwrap_fallback(answer) -> (result, logscale)

Split a fallback's answer into its result and the result's log scale. For an answer built with
[`with_logscale`](@ref)`(message, logscale)`, return the message and `logscale`. The log scale is
a number or an [`UndefinedLogScale`](@ref) with its cause, such as `:unnormalised_product` for an
unnormalised density whose normaliser a form constraint computes. For any other answer, return
the answer and `UndefinedLogScale(:fallback)`.
"""
unwrap_fallback(answer::WithLogScale) = (answer.result, answer.logscale)
unwrap_fallback(answer) = (answer, UndefinedLogScale(:fallback))

"""
    WithOutcome(answer, outcome)

A rule fallback's answer paired with how it was computed, as [`with_outcome`](@ref) builds it. An
engine takes it apart with [`unwrap_outcome`](@ref) before anything else; no rule receives one.
"""
struct WithOutcome{A, O}
    answer::A
    outcome::O
end

"""
    with_outcome(answer, outcome)

Pair a rule fallback's answer, which is a message, a joint marginal or an average energy, with a
description of how the fallback computed it. The outcome is plain data, such as
`(method = :joint_laplace, converged = true, iterations = 6)`. An engine passes it on to its
events, where an inference report can read it. An answer with a log scale is wrapped from the
outside: `with_outcome(with_logscale(message, logscale), outcome)`.

See also [`unwrap_outcome`](@ref).
"""
with_outcome(answer, outcome) = WithOutcome(answer, outcome)

"""
    unwrap_outcome(answer) -> (answer, outcome)

Split a fallback's answer into the answer and the outcome declared with
[`with_outcome`](@ref). For any other answer, the outcome is `nothing`. An engine calls this
first; for a message, it then passes the answer to [`unwrap_fallback`](@ref).
"""
unwrap_outcome(answer::WithOutcome) = (answer.answer, answer.outcome)
unwrap_outcome(answer) = (answer, nothing)

# One untyped default, so that a fallback's own method, `call_fallback(::MyFallback, node, target,
# algorithm, ctx, args)`, is more specific than it for every target
three_argument_fallback(fallback, node, target::Union{Target, IndexedTarget}, args) = fallback(node, target, args)
three_argument_fallback(fallback, node, target::ClusterTarget, args) = nothing

"""
    call_energy_fallback(fallback, node, algorithm, ctx, args)

Consult the rule `fallback` for the average energy of a node, its term of the free energy, when
the node has none defined. The default returns `nothing`, so a fallback written for messages
does not change the free energy. A fallback type answers by defining a method, as for
[`call_fallback`](@ref).
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
