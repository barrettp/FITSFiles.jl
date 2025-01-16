####    Image HDU functions

struct ImageFormat
    type::Type
    leng::Int64
    shape::Tuple
    name::String
    zero::Union{Real, Nothing}
    scal::Union{Real, Nothing}
    null::Union{String, Nothing}
    dmin::Union{Real, Nothing}
    dmax::Union{Real, Nothing}
end

function create_header(::Type{Image}, cards::Vector{Card}, data::AbstractArray, kwds)
    N = ndims(data)
    #  create mandatory (required) header cards and remvove them from the deck if necessary
    required = Vector{Card}(undef, 3+N) 
    required[1] = popat!(cards, "XTENSION", Card("XTENSION", "IMAGE   "))
    required[2] = popat!(cards, "BITPIX", Card("BITPIX", TYPE2BITS[eltype(data)]))
    required[3] = popat!(cards, "NAXIS",  Card("NAXIS", N))
    required[4:3+N] .= [popat!(cards, "NAXIS$j", Card("NAXIS$j", size(data)[j])) for j = 1:N]
    #  append remaining cards in deck, but first remove the END card
    popat!(cards, "END")
    M = length(cards)
    kards = Vector{Card}(undef, 4+N+M)
    kards[1:3+N] .= required
    kards[4+N:3+N+M] .= cards
    kards[4+N+M] = Card("END")
    return kards
end

function create_data(::Type{Image}, cards::Vector{Card})
    #  Create simple N-dimensional array of zeros of type BITPIX
    zeros(TYPE2BITS(cards["BITPIX"]), [cards["NAXIS"*string(j)] for j=1:cards["NAXIS"]]...)
end

function read(io::IO, type::Type{Image}, cards::Vector{Card}; kwds...)
    #  Calculate the length of the array in bytes
    dtype, nbytes = datatype(cards), datalen(cards)
    #  Calculate the number of 2880 byte blocks
    nbloks = div(nbytes, BLOCKLEN, RoundUp)
    if nbytes > 0
        #  Convert truncated bytes to appropriate data type, endianness, and shape.
        data = reshape(
            ntoh.(reinterpret(dtype, Base.read(io, BLOCKLEN*nbloks)[1:nbytes])),
            datashape(cards)...)

        #  Check for non-default integer types
        if dtype in BLANKTYPE && haskey(cards, "BLANK")
            data[cards["BLANK"] .== data] .= missing
        end

        bzero = get(cards, "BZERO", zero(dtype))
        if bzero in keys(TEMPTYPE)
            #  Convert data to intermediate data type, add integer BZERO value,
            #  and convert to output type.
            ttype, otype = TEMPTYPE[bzero], OUTTYPE[dtype]
            data  = otype.(zero(ttype) .+ map(x -> !ismissing(x) ? ttype(x) : x, data))
        else
            #  Apply BZERO and BSCALE and convert to output type.
            otype = OUTTYPE[dtype]
            scale = otype(get(cards, "BSCALE", one(otype)))
            data  = zero(otype) .+ scale.*map(x -> !ismissing(x) ? otype(x) : x, data)
        end
    else
        data = OUTTYPE[dtype][]
    end
    #  Append units
    if haskey(cards, "BUNIT") data = data*uparse(cards["BUNIT"]) end

    ####    Get WCS keywords
    data
end

function write(io::IO, type::Type{Image}, cards::Vector{Card}; kwds...)
end

function verify!(type::Type{Image}, cards::Vector{Card})
end
