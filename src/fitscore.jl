####    FITS type    ####

"""

minmax: constrain an array to be within the range of the minimum and maximum values.
"""
function Fits(io::IO; kwds...)
    hdus = HDU{<:AbstractHDU}[]
    while !eof(io)
        push!(hdus, read(io, HDU; kwds...))
    end
    hdus
end

function Base.haskey(hdus::Vector{HDU}, key::AbstractHDU)
    for hdu in hdus
        if typeofhdu(hdu) == key
            return true
        end
    end
    false
end

function Base.getindex(hdus::Vector{HDU}, key::AbstractHDU)
    for hdu in hdus
        if typeofhdu(hdu) == key
            return hdu
        end
    end
    throw(KeyError(key))
end
