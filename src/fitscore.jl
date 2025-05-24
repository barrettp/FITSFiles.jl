####    FITS type    ####

#   Verify that first HDU is Primary or Random
#   Verify that first HDU has EXTEND keyword set
#   


"""
    fits(io::IO; <keywords>)
    fits(filename::AbstractString; <keywords>)

Open and read a FITS file, returning a vector of header-data units (HDUs).

The default data stucture for Random and Bintable HDUs is a named tuple of arrays.

# Keywords

- `record::Bool=false`: structure the data as a list of records
- `scale::Bool=true`: apply the scale and zero keywords to the data
"""
function fits(io::IO; kwds...)
    hdus = HDU{<:AbstractHDU}[]
    while !eof(io)
        push!(hdus, read(io, HDU; kwds...))
    end
    hdus
end

function fits(file::AbstractString; kwds...)
    io = open(file)
    hdus = fits(io; kwds...)
    close(io)
    hdus
end

"""
   write(io::IO, hdus::Vector{HDU})
   write(filename::AbstractString, hdus::Vector{HDU})

Write a vector of header-data units (HDUs) to a file.
"""
function write(io::IO, hdus::Vector{HDU})
    for hdu in hdus
        FITS.write(io, hdu)
    end
end

function write(file::AbstractString, hdus::Vector{HDU})
    io = open(file, write=true)
    FITS.write(io, hdus)
    close(io)
end

"""
    info(hdus::Vector{HDU})

Briefly describe the list of header-data units (HDUs).
"""
function info(hdus::Vector{HDU})
    for hdu in hdus
        info(hdu)
    end
end

function Base.haskey(hdus::Vector{HDU}, key::Type{<:AbstractHDU})
    for hdu in hdus
        if typeofhdu(hdu) == key
            return true
        end
    end
    false
end

function Base.getindex(hdus::Vector{HDU}, key::Type{<:AbstractHDU})
    for hdu in hdus
        if typeofhdu(hdu) == key
            return hdu
        end
    end
    throw(KeyError(key))
end

function Base.getindex(hdus::Vector{HDU}, key::AbstractString)
    for hdu in hdus
        if haskey(hdu.cards, "EXTNAME") &&
            rstrip(hdu.cards["EXTNAME"]) == rstrip(key)
            return hdu
        end
    end
    throw(KeyError(key))
end
