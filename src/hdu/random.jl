struct RandomFormat
    type::Type
    slice::UnitRange{Int64}
    leng::Int64
    shape::Tuple
    name::String
    zero::Union{Real, Nothing}
    scal::Union{Real, Nothing}
end

function create_header(::Type{Random}, cards::Vector{Card}, data::AbstractArray, kwds)
    data_1 = last(data[1][end])
    println("$(cards["BITPIX"]), $(TYPE2BITS[eltype(data_1)]), $(size(data_1)), $(length(data[1])-1), $(length(data))")
    N, P, G = ndims(data_1), length(data[1])-1, length(data)
    #  create mandatory (required) header cards and remvove them from the deck if necessary
    required = Vector{Card}(undef, 7+N)
    required[1] = popat!(cards, "SIMPLE", Card("SIMPLE", true))
    required[2] = popat!(cards, "BITPIX", Card("BITPIX", TYPE2BITS[eltype(data_1)]))
    required[3] = popat!(cards, "NAXIS",  Card("NAXIS", N))
    required[4] = popat!(cards, "NAXIS1", Card("NAXIS1", 0))
    required[5:4+N] .= [popat!(cards, "NAXIS$j", Card("NAXIS$j", size(data_1)[j-1]))
        for j = 2:N+1]
    required[5+N] = popat!(cards, "GROUP", Card("GROUP", true))
    required[6+N] = popat!(cards, "PCOUNT", Card("PCOUNT", P))
    required[7+N] = popat!(cards, "GCOUNT", Card("GCOUNT", G))
    #  append remaining cards in deck, but first remove the END card
    # popat!(cards, "END")
    M = length(cards)
    kards = Vector{Card}(undef, 8+N+M)
    kards[1:7+N] .= required
    kards[8+N:7+N+M] .= cards
    # kards[8+N+M] = Card("END")
    return kards
end

function read(io::IO, ::Type{Random}, cards::Vector{Card}; kwds...)
    begpos = position(io)
    #  Calculate the length of the array in bytes
    dtype = datatype(cards)
    shape = Tuple([cards["NAXIS$j"] for j = 2:cards["NAXIS"]])
    L, M  = prod(shape), sizeof(dtype)
    G, P  = Int(get(cards, "GCOUNT", 1)), Int(get(cards, "PCOUNT", 0))
    #  Get format
    fmts  = get_format(Random, cards)
    #  Read data table
    #     data  = [NamedTuple(addfields([read(io, fmt) for fmt in fmts])) for j = 1:N]
    data = [[read(io, fmt; kwds...) for fmt in fmts] for j = 1:G]
    #  Seek to the end of the block
    seek(io, begpos + BLOCKLEN*div(M*G*(P + L), BLOCKLEN, RoundUp))
    data
end

function write(io::IO, ::Type{Random}, cards::Vector{Card}, data::AbstractArray; kwds...)
end

function verify!(::Type{Random}, cards::Vector{Card})
end

function get_format(::Type{Random}, cards::Vector{Card})
    type  = BITS2TYPE[cards["BITPIX"]]
    bytes = sizeof(type)
    k, nparams = 0, cards["PCOUNT"]
    fmts = Vector{RandomFormat}(undef, nparams+1)

    for j = 1:nparams
        leng = 1
        pname = get(cards, "PTYPE$j", "")
        pscal = convert(type, get(cards, "PSCAL$j", one(type)))
        pzero = convert(type, get(cards, "PZERO$j", zero(type)))
        fmts[j] = RandomFormat(type, k+1:k+leng*bytes, leng, (1,), pname, pzero, pscal)
        k += leng*bytes
    end
    leng  = prod(Tuple([cards["NAXIS$j"] for j = 2:cards["NAXIS"]]))
    shape = Tuple([cards["NAXIS$j"] for j = 2:cards["NAXIS"]])
    fmts[nparams+1] =
        RandomFormat(type, k+1:k+leng*bytes, leng, shape, "data", zero(type), one(type))
    println(fmts)
    fmts
end

function addfields(fields::Vector)
    [sym => (+)(last.(fields[findall(x -> x == sym, first.(fields))])...)
     for sym in unique(first.(fields))]
end

function read(io::IO, fmt::RandomFormat; scale=true)
    if fmt.leng == 1
        field = (scale ? fmt.zero + fmt.scal : one(fmt.type))*ntoh(Base.read(io, fmt.type))
    else
        field = reshape((scale ? fmt.zero .+ fmt.scal : one(fmt.type)).*ntoh.([
            Base.read(io, fmt.type) for j=1:fmt.leng]), fmt.shape)
    end
    # isempty(fmt.name) ? field : Symbol(lowercase(rstrip(fmt.name))) => field
    isempty(fmt.name) ? field : rstrip(fmt.name) => field
end
