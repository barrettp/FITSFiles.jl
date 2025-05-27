using Documenter, FTIS

makedocs(;
    modules = [FITS],
    sitename = "FITS.jl",
    authors = "Paul Barrett",
    format = Documenter.HTML(;
        assets = ["assets/custom.css"],
        sidebar_sitename = false,
        collapselevel = 1,
        warn_outdated = true,
    ),
    warnonly = [:missing_docs],
    pages = [
        "Home" => "index.md",
        "HDU" => Any[
            "Primary" => "hdu/primary.md",
            "Random" => "hdu/random.md",
            "Image" => "hdu/image.md",
            "Table" => "hdu/table.md",
            "Bintable" => "hdu/bintable.md",
            "ZImage" => "hdu/zimage.md",
            "ZTable" => "hdu/ztable.md",
            "Conform" => "hdu/conform.md"
        ]
        "API" = > "api.md"
    ],
)

deployhooks(;
    repo = "github.com/barrettp/FITS.jl/docs",
    devbranch = "main",
    push_preview = true
)
