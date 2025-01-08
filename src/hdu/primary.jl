####    Primary HDU functions

struct PrimaryFormat
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


###  1. Check that cards and data are equal

function create_header(::Type{Primary}, cards::Vector{Card}, data::AbstractArray, kwds)
    N = ndims(data)
    #  create mandatory (required) header cards and remvove them from the deck if necessary
    required = Vector{Card}(undef, 3+N) 
    required[1] = popat!(cards, "SIMPLE", Card("SIMPLE", true))
    required[2] = popat!(cards, "BITPIX", Card("BITPIX", TYPE2BITS[eltype(data)]))
    required[3] = popat!(cards, "NAXIS",  Card("NAXIS", N))
    required[4:3+N] .= [popat!(cards, "NAXIS$j", Card("NAXIS$j", size(data)[j])) for j = 1:N]
    #  append remaining cards in deck, but first remove the END card
    # popat!(cards, "END")
    M = length(cards)
    kards = Vector{Card}(undef, 4+N+M)
    kards[1:3+N] .= required
    kards[4+N:3+N+M] .= cards
    # kards[4+N+M] = Card("END")
    return kards
end

function create_data(::Type{Primary}, cards::Vector{Card})
    #  Create simple N-dimensional array of zeros of type BITPIX
    zeros(datatype(cards), datalen(cards)...)
end

function read(io::IO, ::Type{Primary}, cards::Vector{Card}; kwds...)
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

function write(io::IO, ::Type{Primary}, cards::Vector{Card}, data::AbstractArray; kwds...)
    otype, itype, nbytes = datatype(cards), eltype(data), datalen(cards)

    if nbytes > 0
        if bzero in keys(TEMPTYPE)
            bzero, scale = get(cards, "BZERO", zero(itype)), get(cards, "BSCALE", one(itype))
            #  Subtract zero and round to output type.
            nbytes = Base.write(io, hton.(round(otype, data .- bzero)))
        else
            nbytes = Base.write(io, hton.((data .- bzero)./scale))
        end

        #  Check for non-default integer types
        if otype in BLANKTYPE && haskey(cards, "BLANK")
            data[data .== missing] .= cards["BLANK"]
        end

        Base.write(io, hton.(data))
    end

    #  Pad data to 2880 byte blocks
    nbloks = div(nbytes, BLOCKLEN, RoundUp)
    pbytes = Base.write(io, zeros(UInt8, nbloks*BLOCKLEN-nbytes))
end

function verify!(::Type{Primary}, cards::Vector{Card}, correct::Bool=true)
    (&)([cards[j].key == key for (j, key) in
         enumerate(vcat(["SIMPLE", "BITPIX", "NAXIS"],
                        ["NAXIS"*string(j) for j = 1:cards["NAXIS"]]))]...)
end
