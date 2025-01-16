####    ZTable HDU functions

using CodecZlib
#  add Rice, PLIO, Hcompress, and No compression algorithms

struct ZTableFormat
    type::Type
end

function getformat(::Type{ZTable}, cards::Vector{Card})
end

function read(io::IO, ::Type{ZTable}, cards::Vector{Card}; kwds...)
end

function write(io::IO, ::Type{ZTable}, cards::Vector{Card}; kwds...)
end

function verify!(::Type{ZTable}, cards::Vector{Card}; kwds...)
end

