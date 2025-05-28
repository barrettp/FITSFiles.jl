
using Documenter, FITSFiles

makedocs(;
    modules = [FITSFiles],
    sitename = "FITSFiles.jl",
    authors = "Paul Barrett",
    format = Documenter.HTML(;
        assets = ["assets/custom.css"],
        sidebar_sitename = false,
        collapselevel = 1,
        warn_outdated = true
    ),
    warnonly = [:missing_docs],
    pages = [
        "FITSFiles" => "index.md"
    ]
)

deploydocs(;
    repo = "github.com/barrettp/FITSFiles.jl/docs",
    devbranch = "main",
    push_preview = true
)
