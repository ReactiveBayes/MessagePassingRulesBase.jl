using MessagePassingRulesBase
using Documenter

DocMeta.setdocmeta!(MessagePassingRulesBase, :DocTestSetup, :(using MessagePassingRulesBase); recursive = true)

makedocs(;
    modules = [MessagePassingRulesBase],
    authors = "Dmitry Bagaev <bvdmitri@gmail.com> and contributors",
    sitename = "MessagePassingRulesBase.jl",
    format = Documenter.HTML(;
        canonical = "https://reactivebayes.github.io/MessagePassingRulesBase.jl", edit_link = "main", assets = String[]
    ),
    pages = ["Home" => "index.md"]
)

deploydocs(; repo = "github.com/ReactiveBayes/MessagePassingRulesBase.jl", devbranch = "main")
