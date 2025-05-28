
using Documenter, FITS

makedocs(;
    modules = [FITS],
    sitename = "FITS.jl",
    authors = "Paul Barrett",
    format = Documenter.HTML(;
        assets = ["assets/custom.css"],
        sidebar_sitename = false,
        collapselevel = 1,
        warn_outdated = true
    ),
    warnonly = [:missing_docs],
    pages = [
        "FITS" => "index.md"
    ]
)

deploydocs(;
    repo = "github.com/barrettp/FITS.jl/docs",
    devbranch = "main",
    push_preview = true
)
