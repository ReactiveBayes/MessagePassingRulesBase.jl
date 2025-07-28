export PredefinedNodeFunctionalForm, UndefinedNodeFunctionalForm, is_predefined_node
export Deterministic, Stochastic, isdeterministic, isstochastic, sdtype
export nodefunction
export as_node_symbol
export collect_factorisation, collect_meta, default_meta
export AbstractFactorNode,
    functionalform,
    getinterfaces,
    getinterface,
    getinboundinterfaces,
    getlocalclusters,
    interfaceindex,
    interfaceindices
export interfaces, inputinterfaces, alias_interface

export @node

"""
    PredefinedNodeFunctionalForm

Trait specification for an object that has been marked as a valid factor node. 
The [`@node`](@ref) macro sets this automatically.

See also: [`is_predefined_node`](@ref), [`UndefinedNodeFunctionalForm`](@ref)
"""
struct PredefinedNodeFunctionalForm end

"""
    UndefinedNodeFunctionalForm

Trait specification for an object that has **not** been marked as a factor node.
Note that it does not necessarily mean that the object is not a valid factor node, but rather that it has not been marked as such. The underlying inference engine (e.g. ReactiveMP.jl) may support arbitrary objects as factor nodes, but they may require manual specification of the approximation method. 

See also: [`is_predefined_node`](@ref), [`PredefinedNodeFunctionalForm`](@ref)
"""
struct UndefinedNodeFunctionalForm end

"""
    is_predefined_node(object)

Determines if the `object` has been marked as a factor node with the `@node` macro.
Returns either `PredefinedNodeFunctionalForm()` or `UndefinedNodeFunctionalForm()`.

See also: [`PredefinedNodeFunctionalForm`](@ref), [`UndefinedNodeFunctionalForm`](@ref)
"""
is_predefined_node(object) = UndefinedNodeFunctionalForm()

## Node types

"""
    Deterministic

`Deterministic` object used to parametrize factor node object with determinstic type of relationship between variables.

See also: [`Stochastic`](@ref), [`isdeterministic`](@ref), [`isstochastic`](@ref), [`sdtype`](@ref)
"""
struct Deterministic end

"""
    Stochastic

`Stochastic` object used to parametrize factor node object with stochastic type of relationship between variables.

See also: [`Deterministic`](@ref), [`isdeterministic`](@ref), [`isstochastic`](@ref), [`sdtype`](@ref)
"""
struct Stochastic end

"""
    isdeterministic(node)

Function used to check if factor node object is deterministic or not. Returns true or false.

See also: [`Deterministic`](@ref), [`Stochastic`](@ref), [`isstochastic`](@ref), [`sdtype`](@ref)
"""
function isdeterministic end

"""
    isstochastic(node)

Function used to check if factor node object is stochastic or not. Returns true or false.

See also: [`Deterministic`](@ref), [`Stochastic`](@ref), [`isdeterministic`](@ref), [`sdtype`](@ref)
"""
function isstochastic end

isdeterministic(::Deterministic)       = true
isdeterministic(::Type{Deterministic}) = true
isdeterministic(::Stochastic)          = false
isdeterministic(::Type{Stochastic})    = false

isstochastic(::Stochastic)          = true
isstochastic(::Type{Stochastic})    = true
isstochastic(::Deterministic)       = false
isstochastic(::Type{Deterministic}) = false

"""
    sdtype(object)

Returns either `Deterministic` or `Stochastic` for a given object (if defined).

See also: [`Deterministic`](@ref), [`Stochastic`](@ref), [`isdeterministic`](@ref), [`isstochastic`](@ref)
"""
sdtype(any) = error("Unknown if an object of type `$(typeof(any))` is stochastic or deterministic.")

# Any `Type` is considered to be a deterministic mapping unless stated otherwise (By convention, any `Distribution` type is not deterministic)
# E.g. `Matrix` is not an instance of the `Function` abstract type, however we would like to pretend it is a deterministic function
sdtype(::Type{T}) where {T} = Deterministic()
sdtype(::Function)          = Deterministic()

## Node function

"""
    nodefunction(::Type{T}) where {T}

Returns a function that represents a node of type `T`. 
The function typically takes arguments that represent the node's input and output variables in the same order as defined in the `@node` macro.
"""
function nodefunction end

## Node symbol

"""
    as_node_symbol(type)

Returns a symbol associated with a node `type`. 
"""
function as_node_symbol end

as_node_symbol(fn::F) where {F <: Function} = Symbol(fn)

## Factorisation

"""
    collect_factorisation(nodetype, factorisation)

This function converts given factorisation to a correct internal factorisation representation for a given node.
"""
function collect_factorisation end

## Meta objects 

"""
    collect_meta(nodetype, meta)

This function converts given meta object to a correct internal meta representation for a given node. Fallbacks to `default_meta` in case if meta is `nothing`.

See also: [`default_meta`](@ref)
"""
function collect_meta end

collect_meta(fform::F, ::Nothing) where {F} = default_meta(fform)
collect_meta(fform::F, meta::Any) where {F} = meta

"""
    default_meta(nodetype)

Returns default meta object for a given node type.

See also: [`collect_meta`](@ref)
"""
default_meta(fform) = nothing

## Abstract factor node type

abstract type AbstractFactorNode end

function functionalform(factornode::AbstractFactorNode)
    error("`functionalform` is not implemented for $(typeof(factornode))")
end

function getinterfaces(factornode::AbstractFactorNode)
    error("`getinterfaces` is not implemented for $(typeof(factornode))")
end

function getinterface(factornode::AbstractFactorNode, index)
    error("`getinterface` is not implemented for $(typeof(factornode))")
end

# `getinboundinterfaces` skips the first interface, which is assumed to be the output interface
function getinboundinterfaces(factornode::AbstractFactorNode)
    error("`getinboundinterfaces` is not implemented for $(typeof(factornode))")
end

function getlocalclusters(factornode::AbstractFactorNode)
    error("`getlocalclusters` is not implemented for $(typeof(factornode))")
end

function sdtype(factornode::AbstractFactorNode)
    return sdtype(functionalform(factornode))
end

function interfaceindex(factornode::AbstractFactorNode, iname::Symbol)
    error("`interfaceindex` is not implemented for $(typeof(factornode))")
end

function interfaceindices(factornode::AbstractFactorNode, iname::Symbol)
    error("`interfaceindices` is not implemented for $(typeof(factornode))")
end

function interfaceindices(factornode::AbstractFactorNode, inames::NTuple{N, Symbol}) where {N}
    error("`interfaceindices` is not implemented for $(typeof(factornode))")
end

## Macro interface for the `@node` macro

"""
    interfaces(fform)

Returns a `Val` object with a tuple of interface names for a given factor node type. Returns `nothing` for unknown functional form.
"""
interfaces(fform) = nothing

"""
    inputinterfaces(fform)

Similar to `interfaces`, but returns a `Val` object with a tuple of **input** interface names for a given factor node type. Returns `nothing` for unknown functional form.
"""
inputinterfaces(fform) = nothing

"""
    alias_interface(factor_type, index, name)

Converts the given `name` to a correct interface name for a given factor node type and index.
"""
function alias_interface end

node_expression_extract_interface(s::Symbol) = (s, [])

function node_expression_extract_interface(e::Expr)
    if @capture(e, (s_, aliases = [aliases__]))
        if !all(alias -> alias isa Symbol, aliases)
            error(lazy"Aliases should be pure symbols. Got expression in $(aliases).")
        end
        return (s, aliases)
    else
        error(lazy"Unknown interface specification: $(e)")
    end
end

function generate_node_expression(node_fform, node_type, node_interfaces)
    # Assert that the node type is either Stochastic or Deterministic, and that all interfaces are symbols
    @assert node_type ∈ [:Stochastic, :Deterministic]
    @assert length(node_interfaces.args) > 0

    interfaces = map(node_expression_extract_interface, node_interfaces.args)

    # Determine whether we should dispatch on `typeof($fform)` or `Type{$node_fform}`
    dispatch_type = if @capture(node_fform, typeof(fform_))
        :(typeof($fform))
    else
        :(Type{<:$node_fform})
    end

    foreach(interfaces) do (name, aliases)
        @assert !occursin('_', string(name)) "Node interfaces names (and aliases) must not contain `_` symbol in them, found in `$(name)`."
        foreach(aliases) do alias
            @assert !occursin('_', string(alias)) "Node interfaces names (and aliases) must not contain `_` symbol in them, found in `$(alias)`."
        end
    end

    alias_corrections = Expr(:block)
    alias_corrections.args = map(enumerate(interfaces)) do (index, (name, aliases))
        # The `index` and `name` variables are defined further in the `alias_interface` function
        quote
            # TODO: (bvdmitri) maybe reserving `in` here is not a good idea, discuss with Wouter
            if index === $index &&
                (name === :in || name === $(QuoteNode(name)) || Base.in(name, ($(map(QuoteNode, aliases)...),)))
                return $(QuoteNode(name))
            end
        end
    end

    collect_factorisation_fn = if node_type == :Stochastic
        :(MessagePassingRulesBase.collect_factorisation(::$dispatch_type, factorisation::Tuple) = factorisation)
    else
        :(
            MessagePassingRulesBase.collect_factorisation(::$dispatch_type, factorisation::Tuple) =
                ($(ntuple(identity, length(interfaces))),)
        )
    end

    doctype   = rpad(dispatch_type, 30)
    docsdtype = rpad(node_type, 15)
    docedges  = join(map(((name, aliases),) -> string(name, !isempty(aliases) ? string(" (or ", join(aliases, ", "), ")") : ""), interfaces), ", ")
    doc       = """    
        $doctype : $docsdtype : $docedges
    The `$(node_fform)` has been marked as a valid `$(node_type)` factor node with the `@node` macro with `[ $(docedges) ]` interfaces.
    """

    # For `Stochastic` nodes the `nodefunctions` are pre-generated automatically 
    #   by calling the `corresponding` logpdf
    nodefunctions = if node_type == :Stochastic
        nodefunctionargnames = first.(interfaces)

        # The very first function is a generic method that only accepts type and returns 
        # a function that fallbacks to calculate the logpdf of the distribution
        fncollection = [
            :(
                MessagePassingRulesBase.nodefunction(::$dispatch_type) =
                    (; $(nodefunctionargnames...)) -> MessagePassingRulesBase.BayesBase.logpdf(
                        ($node_fform)($(nodefunctionargnames[2:end]...)), $(nodefunctionargnames[1])
                    )
            )
        ]

        # The rest are individual node functions in each direction
        for interface in interfaces
            interfacename = first(interface)
            edgespecificfn = :(
                MessagePassingRulesBase.nodefunction(::$dispatch_type, ::Val{$(QuoteNode(interfacename))}; kwargs...) = begin
                    return let ckwargs = kwargs
                        ($interfacename) -> MessagePassingRulesBase.nodefunction($node_fform)(;
                            $interfacename = $interfacename, ckwargs...
                        )
                    end
                end
            )
            push!(fncollection, edgespecificfn)
        end

        _block = Expr(:block)
        _block.args = fncollection
        _block
    else
        :(nothing)
    end

    # Define the necessary function types
    result = quote
        @doc $doc MessagePassingRulesBase.is_predefined_node(::$dispatch_type) =
            MessagePassingRulesBase.PredefinedNodeFunctionalForm()

        MessagePassingRulesBase.sdtype(::$dispatch_type)          = (MessagePassingRulesBase.$node_type)()
        MessagePassingRulesBase.interfaces(::$dispatch_type)      = Val($(Tuple(map(first, interfaces))))
        MessagePassingRulesBase.inputinterfaces(::$dispatch_type) = Val($(Tuple(map(first, interfaces[(begin + 1):end]))))

        $collect_factorisation_fn
        $nodefunctions

        function MessagePassingRulesBase.alias_interface(dispatch_type::$dispatch_type, index, name)
            $alias_corrections
            # If we do not return from the `alias_corrections` we throw an error
            error(lazy"Don't know how to alias interface $(name) in $(index) for $(dispatch_type)")
        end
    end

    return result
end

"""
    @node(fformtype, sdtype, interfaces_list)


`@node` macro creates a node for a `fformtype` type object. To obtain a list of predefined nodes use `?is_predefined_node`.

# Arguments

- `fformtype`: Either an existing type identifier, e.g. `Normal` or a function type identifier, e.g. `typeof(+)`
- `sdtype`: Either `Stochastic` or `Deterministic`. Defines the type of the functional relationship
- `interfaces_list`: Defines a fixed list of edges of a factor node, by convention the first element should be `out`. Example: `[ out, mean, variance ]`

Note: `interfaces_list` must not include names that contain `_` symbol in them, as it is reserved to identify joint posteriors around the node object.

# Examples
```julia

struct MyNormalDistribution
    mean :: Float64
    var  :: Float64
end

@node MyNormalDistribution Stochastic [ out, mean, var ]
```

```julia

@node typeof(+) Deterministic [ out, in1, in2 ]
```

# List of available nodes

See `?is_predefined_node`.
"""
macro node(node_fform, node_type, node_interfaces)
    return esc(generate_node_expression(node_fform, node_type, node_interfaces))
end