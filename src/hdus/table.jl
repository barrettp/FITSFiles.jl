####    Table HDU functions

const TABLEFMT = Regex("(?<t>[AIFED])(?<w>\\d+).?(?<f>\\d+)?")

const TABLETYPE = Dict(
    "A" => String, "I" => Int64, "F" => Float64, "E" => Float64, "D" => Float64)

struct TableFormat
    type::Type
    slice::UnitRange{Int64}
    name::String
    unit::String
    disp::String
    zero::Union{Real, Nothing}
    scal::Union{Real, Nothing}
    null::Union{String, Nothing}
    dmin::Union{Real, Nothing}
    dmax::Union{Real, Nothing}
    lmin::Union{Real, Nothing}
    lmax::Union{Real, Nothing}
end

function create_header(::Type{Table}, cards::Vector{Card}, data::AbstractArray, kwds)
    if ndims(data) != 2
        throw(ArgumentError("incorrect number of dimesions: != 2"))
    end
    N = 2
    #  create mandatory header cards and remvove them from the deck if necessary
    required = Vector{Card}(undef, 3+N)
    required[1] = popat!(cards, "XTENSION", Card("XTENSION", "TABLE   "))
    required[2] = popat!(cards, "BITPIX", Card("BITPIX", TYPE2BITS[eltype(data)]))
    required[3] = popat!(cards, "NAXIS",  Card("NAXIS", 2))
    required[4:3+N] .= [popat!(cards, "NAXIS$j", Card("NAXIS$j", size(data)[j])) for j = 1:N]
    #  append remaining cards in deck, but first remove the END card
    popat!(cards, "END")
    M = length(cards)
    kards = Vector{Card}(undef, 36*div(3+N+M, 36, RoundUp))
    kards[1:3+N] .= required
    kards[4+N:3+N+M] .= cards
    kards[4+N+M] = Card("END")
    kards[5+N+M:end] .= repeat([Card()], length(kards)-(4+N+M))
    return kards
end

function create_data(::Type{Table}, cards::Vector{Card})
    #  Create simple N-dimensional array of zeros of type BITPIX
    zeros(TYPE2BITS(cards["BITPIX"]), [cards["NAXIS$j"] for j=1:cards["NAXIS"]]...)
end

function read(io::IO, type::Type{Table}, cards::Vector{Card}; kwds...)
    begpos = position(io)
    #  Get length and number of character rows
    M, N  = datashape(cards)
    #  Get table format
    fmts  = getformat(Table, cards)
    #  Read ASCII table into buffer
    buffer = [String(Base.read(io, M)) for j = 1:N]
    #  Read buffer
    data = [(; collect(read(buffer[j], fmt; kwds) for fmt in fmts)...) for j = 1:N]
    #  Set minimum and maximum array values
    #  Seek to the end of the block
    seek(io, begpos + BLOCKLEN*div(M*N, BLOCKLEN, RoundUp))
    data
end

function write(type::Type{Table}, io::IO, cards::Vector{Card})
end

function verify!(type::Type{Table}, cards::Vector{Card})
end

function getformat(::Type{Table}, cards::Vector{Card})
    k, nfields = 0, cards["TFIELDS"]
    fmts = Vector{TableFormat}(undef, nfields)
    for j = 1:nfields
        fmt = match(TABLEFMT, cards["TFORM$j"])

        type  = TABLETYPE[fmt[:t]]
        leng  = Base.parse(Int64, fmt[:w])
        k     = cards["TBCOL$j"]
        name  = get(cards, "TTYPE$j", "")
        unit  = get(cards, "TUNIT$j", "")
        disp  = get(cards, "TDISP$j", "")
        tzero = get(cards, "TZERO$j", type <: String ? nothing : type(0))
        tscal = get(cards, "TSCAL$j", type <: String ? nothing : type(1))
        null  = get(cards, "TNULL$j", nothing)
        dmin  = get(cards, "TDMIN$j", nothing)
        dmax  = get(cards, "TDMAX$j", nothing)
        lmin  = get(cards, "TLMIN$j", nothing)
        lmax  = get(cards, "TLMAX$j", nothing)

        fmts[j] = TableFormat(type, k:k+leng, name, unit, disp, tzero, tscal,
                              null, dmin, dmax, lmin, lmax)
    end
    fmts
end

function read(row::AbstractString, fmt::TableFormat; kwds...)
    field = row[fmt.slice]
    if fmt.type <: AbstractString
        value = fmt.type(field)
    elseif (!isnothing(fmt.null) && fmt.null == field) ||
        field == repeat(' ', length(fmt.slice)) || length(fmt.slice) <= 0
        value = missing
    else
        value = fmt.zero + fmt.scal*Base.parse(
            fmt.type, replace(field, "D" => "e", "E" => "e"))
        if get(kwds, :invalid, false)
            if !isnothing(fmt.lmin) && value < fmt.lmin value = missing end
            if !isnothing(fmt.lmax) && value > fmt.lmax value = missing end
        end
    end
    #  Append units
    if !isnothing(fmt.unit) value *= uparse(fmt.unit) end
    #  Create a Pair for name fields
    isempty(fmt.name) ? value : Symbol(lowercase(rstrip(fmt.name))) => value
end
