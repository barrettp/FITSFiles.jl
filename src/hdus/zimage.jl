####    ZImage HDU functions

using CodecZlib
#  add Rice, PLIO, Hcompress, and No compression algorithms

struct ZImageFormat
    #  Uncompressed image values
    type::Type
    shape::Tuple
    #  Columns
    name::Vector{String}
    #  Compression values
    comp::String
    parm::Vector{Pair}
    tile::Tuple{Int64}
    mask::String
    quant::String
    dithr::Int64
    card::Vector{Card}
end

function getformat(::Type{ZImage}, cards::Vector{Card})
    
end

function read(io::IO, ::Type{ZImage}, cards::Vector{Card}; kwds...)
end

function write(io::IO, ::Type{ZImage}, cards::Vector{Card}; kwds...)
end

function verify!(::Type{ZImage}, cards::Vector{Card}; kwds...)
end
