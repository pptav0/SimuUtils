using SimuUtils
using Documenter

DocMeta.setdocmeta!(SimuUtils, :DocTestSetup, :(using SimuUtils); recursive=true)

makedocs(;
    modules=[SimuUtils],
    authors="Jose Guzman <pepetavo@pm.me> and contributors",
    sitename="SimuUtils.jl",
    format=Documenter.HTML(;
        canonical="https://pptav0.github.io/SimuUtils.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/pptav0/SimuUtils.jl",
    devbranch="main",
)
