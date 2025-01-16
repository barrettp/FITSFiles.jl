####    Bintable HDU functions

#   Add support TTYPEn and TUNITn in data arrays
#   Add support Bit type

struct Bit <: Unsigned end

const BINARYFMT = Regex("(?<r>\\d*)(?<t>[LXBIJKAEDCMPQ])(?<a>\\w*)")

const BINARYTYPE = Dict(
    #  character to type
    "L" => Bool, "X" => Bit, "B" => UInt8, "I" => Int16, "J" => Int32, "K" => Int64,
    "A" => String, "E" => Float32, "D" => Float64, "C" => ComplexF32, "M" => ComplexF64,
    "P" => UInt64, "Q" => UInt128,
    #  type to character
    Bool => "L", Bit => "X", UInt8 => "B", Int16 => "I", Int32 => "J", Int64 => "K",
    String => "A", Float32 => "E", Float64 => "D", ComplexF32 => "C", ComplexF64 => "M",
    UInt64 => "P", UInt128 => "Q")

struct BinaryFormat
    type::Type
    slice::UnitRange{Int64}
    leng::Int64
    supp::String
    #  optional fields
    name::String
    unit::String
    disp::String
    dims::Union{Tuple, Nothing}
    zero::Union{Real, Nothing}
    scal::Union{Real, Nothing}
    null::Union{Int64, Nothing}
    dmin::Union{Real, Nothing}
    dmax::Union{Real, Nothing}
    lmin::Union{Real, Nothing}
    lmax::Union{Real, Nothing}
end

function create_header(::Type{Bintable}, cards::Vector{Card}, data::AbstractArray, kwds)
    #  create mandatory header cards and remvove them from the deck if necessary
    required = Vector{Card}(undef, 8)
    required[1] = popat!(cards, "XTENSION", Card("XTENSION", "BINTABLE"))
    required[2] = popat!(cards, "BITPIX", Card("BITPIX", 8))
    required[3] = popat!(cards, "NAXIS",  Card("NAXIS", 2))
    required[4] = popat!(cards, "NAXIS1", Card("NAXIS1", length(data[1]))) # Fix this!
    required[5] = popat!(cards, "NAXIS2", Card("NAXIS2", length(data)))
    required[6] = popat!(cards, "PCOUNT", Card("PCOUNT", 0))
    required[7] = popat!(cards, "GCOUNT", Card("GCOUNT", 1))
    required[8] = popat!(cards, "TFIELDS", Card("TFIELDS", 0))
    #  append remaining cards in deck, but first remove the END card
    popat!(cards, "END")
    M = length(cards)
    kards = Vector{Card}(undef, 10+M)
    kards[1:8] .= required
    kards[9:8+M] .= cards
    kards[9+M] = Card("END")
    return kards
end

function create_data(::Type{Bintable}, cards::Vector{Card})
    #  Create vector of tuples.
    zeros(TYPE2BITS(cards["BITPIX"]), [cards["NAXIS"*string(j)] for j=1:cards["NAXIS"]]...)
end

function read(io::IO, ::Type{Bintable}, cards::Vector{Card}; kwds...)
    begpos = position(io)
    #  Get shape of the data
    M, N, P = datashape(cards)..., Int(cards["PCOUNT"])
    #  Get record format
    fmts  = getformat(Bintable, cards)
    #  Read data table
    data  = [(; collect(read(io, fmt; kwds...) for fmt in fmts)...) for j = 1:N]
    #  Seek to the beginning of the heap
    seek(io, begpos + Int(get(cards, "THEAP", M*N)))
    #  Read the heap
    ntoh.(Base.read(io, P))
    #  Seek to the end of block
    seek(io, begpos + BLOCKLEN*div(M*N + P, BLOCKLEN, RoundUp))
    data
end

function write(io::IO, ::Type{Bintable}, data::Vector{Tuple})
    #  Get record format
    fmts = setformat(Bintable, data)
    #  Get shape of the data
    M, N = fmts[end].slice[end], length(data)
    #  Write data table
    [[write(io, hton.(fld)) for fld in data[j]] for j = 1:N]
    #  Pad last block with zeros
end

function verify!(::Type{Bintable}, cards::Vector{Card})
end

function getformat(::Type{Bintable}, cards::Vector{Card})
    k, nfields = 0, cards["TFIELDS"]
    fmts = Vector{BinaryFormat}(undef, nfields)
    for j = 1:nfields
        fmt  = match(BINARYFMT, cards["TFORM$j"])

        type = BINARYTYPE[fmt[:t]]
        leng = !isempty(fmt[:r]) ? Base.parse(Int64, fmt[:r]) : 1
        byts = type <: String ? 1 : sizeof(type)
        addn = fmt[:a]
        name = get(cards, "TTYPE$j", "")
        unit = get(cards, "TUNIT$j", "")
        disp = get(cards, "TDSIP$j", "")
        dims = eval(Meta.parse(get(cards, "TDIM$j", "")))
        zero = get(cards, "TZERO$j", type <: Union{Bool, Bit, String} ? nothing : type(0))
        scal = get(cards, "TSCAL$j", type <: Union{Bool, Bit, String} ? nothing : type(1))
        null = get(cards, "TNULL$j", nothing)
        dmin = get(cards, "TDMIN$j", nothing)
        dmax = get(cards, "TDMAX$j", nothing)
        lmin = get(cards, "TLMIN$j", nothing)
        lmax = get(cards, "TLMAX$j", nothing)
        
        fmts[j] = BinaryFormat(type, k+1:k+leng*byts, leng, addn, name, unit, disp,
                               dims, zero, scal, null, dmin, dmax, lmin, lmax)
        k += leng*byts
    end
    fmts
end

function read(io::IO, fmt::BinaryFormat; kwds...)
    if fmt.type <: AbstractString
        value = fmt.type(Base.read(io, length(fmt.slice)))
    elseif fmt.leng == 0
        value = nothing
    elseif fmt.leng == 1
        value = ntoh(Base.read(io, fmt.type))
        if get(kwds, :invalid, false)
            if !isnothing(fmt.lmin) && value < fmt.lmin value = missing end
            if !isnothing(fmt.lmax) && value > fmt.lmax value = missing end
        end
    else
        value = ntoh.([Base.read(io, fmt.type) for j=1:fmt.leng])
        if get(kwds, :invalid, false)
            if !isnothing(fmt.lmin) value[value .< fmt.lmin] .= missing end
            if !isnothing(fmt.lmax) value[value .> fmt.lmax] .= missing end
        end
    end
    #  Append units
    ### if !isnothing(fmt.unit) value *= uparse(fmt.unit) end
    #  Create a Pair for named fields.
    isempty(fmt.name) ? value : Symbol(lowercase(rstrip(fmt.name))) => value
end

function setformat(::Type{Bintable}, data::Vector)
    k, nfields = 0, length(data[1])
    fmts = Vector{BinaryFormat}(undef, nfields)
    for j = 1:nfields
        field = data[1][j]
        if typeof(field) <: AbstractString
            type, leng, byts, dims = typeof(field), length(field), 1, nothing
        elseif typeof(field) <: AbstractArray
            type, leng, byts = eltype(field), length(field), sizeof(eltype(field))
            dims = ndims(field) > 1 ? size(field) : nothing
        else
            type, leng, byts, dims = typeof(field), 1, sizeof(field), nothing
        end
        addn = ""
        name = ""
        unit = ""
        disp = ""
        zero = type <: AbstractString ? nothing : type(0)
        scal = type <: AbstractString ? nothing : type(1)
        null = nothing
        dmin = nothing
        dmax = nothing
        lmin = nothing
        lmax = nothing

        fmts[j] = BinaryFormat(type, k+1:k+leng*byts, leng, addn, name, unit, disp,
                               dims, zero, scal, null, dmin, dmax, lmin, lmax)
        k += leng*byts
    end
    fmts
end

function write(io::IO, fmt::BinaryFormat, field::Any)
    if typeof(field) <: AbstractString
        write(io, rpad(field, length(fmt.slice)))
    elseif isnothing(field)
    elseif fmt.leng == 1
        write(io, hton(field))
    else
        write(io, hton.(field))
    end
end
