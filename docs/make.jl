using Pkg
if Pkg.project().name != "docs"
    Pkg.activate(@__DIR__)
    Pkg.resolve()  # Automatically update deps
end

using CassandraBacktest
using Documenter

DocMeta.setdocmeta!(CassandraBacktest, :DocTestSetup, :(using CassandraBacktest); recursive=true)

makedocs(;
    modules=[CassandraBacktest],
    authors="Michiel van der Meulen <michielvdmeulen@gmail.com> and contributors",
    sitename="CassandraBacktest.jl",
    format=Documenter.HTML(;
        ansicolor=true,
        prettyurls=false, # Set true when building local docs without live serving (working links)
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "API" => "api.md",  # The docs/src/api.md file is created by MvdmPkgTemplate by default
    ],
    repo="https://github.com/michielvdmeulen/CassandraBacktest.jl",
)
