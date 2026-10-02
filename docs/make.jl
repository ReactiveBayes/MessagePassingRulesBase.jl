# The documentation site of MessagePassingRulesBase. Build it with `julia --project=docs docs/make.jl`.
using Documenter, DocumenterInterLinks
using MessagePassingRulesBase

# The site links to no other package's.
links = InterLinks()

DocMeta.setdocmeta!(MessagePassingRulesBase, :DocTestSetup, :(using MessagePassingRulesBase); recursive = true)

makedocs(
    modules = [MessagePassingRulesBase],
    sitename = "MessagePassingRulesBase.jl",
    # Every docstring appears on a page.
    checkdocs = :all,
    plugins = [links],
    pages = [
        "Overview" => "index.md",
        "Tutorials" => [
            "Your first node" => "tutorials/first-node.md",
            "A deterministic node with a group" => "tutorials/groups.md",
            "A node with its own algorithm" => "tutorials/algorithm.md",
        ],
        "Defining nodes" => "nodes.md",
        "Defining rules" => "rules.md",
        "Algorithms and dependencies" => "algorithms.md",
        "Log scales" => "logscales.md",
        "The rule context" => "context.md",
        "Calling rules" => "calling.md",
        "Inspecting rules" => "inspecting.md",
        "Rule fallbacks" => "fallbacks.md",
        "Math helpers" => "math.md",
        "Keyword reference" => "keywords.md",
        "Glossary" => "glossary.md",
        "Internals" => "internals.md",
    ],
    # Pages that show rule results as cards are larger than the defaults allow.
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        example_size_threshold = 400 * 1024, size_threshold_warn = 400 * 1024, size_threshold = 400 * 1024,
    ),
)

deploydocs(
    repo = "github.com/ReactiveBayes/MessagePassingRulesBase.jl.git",
    devbranch = "main",
    push_preview = true,
)
