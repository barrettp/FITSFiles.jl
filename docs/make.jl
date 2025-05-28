
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
        "Home" => "index.md",
        "API" => "api.md",        
        "HDU" => Any[
            "Introduction" => "HDU.md",
            "Primary" => "HDU/primary.md",
            "Random" => "HDU/random.md",
            "Image" => "HDU/image.md",
            "Table" => "HDU/table.md",
            "Bintable" => "HDU/bintable.md",
            "ZImage" => "HDU/zimage.md",
            "ZTable" => "HDU/ztable.md",
            "Conform" => "HDU/conform.md"
        ],
        "Internal API" => "internalapi.md"
    ],
)

deploydocs(;
    repo = "github.com/barrettp/FITS.jl/docs",
    devbranch = "main",
    push_preview = true
)
