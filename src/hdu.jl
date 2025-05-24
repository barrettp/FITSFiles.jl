####    HDU type    ####

abstract type AbstractHDU end

#  Primary HDU
"""
    Primary header-data unit (HDU)

A Primary HDU consists of a vector of cards and optionally a multidimensional
array (<=999 dimensions). The Primary HDU is the first HDU in a vector of HDUs.
"""
struct Primary     <: AbstractHDU end

"""
    Random header-data unit (HDU)

A Random HDU consists of a vector of cards and optionally a vector of records
containing a list of parameters followed by a multidimensional array. The
Random HDU is the first HDU in a vector of HDUs.
"""
struct Random      <: AbstractHDU end

#  Standard HDU Extensions
"""
    Image header-data unit (HDU)

An Image HDU consists of a vector cards and optionally a multidimensional array
(<=999 dimensions).
"""
struct Image       <: AbstractHDU end
"""
    Table header-data unit (HDU)

A Table HDU consists of a vector of cards and optionally a 2-dimensional array
of ASCII data structured as vector of records.
"""
struct Table       <: AbstractHDU end
"""
    Bintable header-data unit (HDU)

A Bintable HDU consists of a vector of cards and optionally a 2-dimensional
array of binary data structured as a vector of records.
"""
struct Bintable    <: AbstractHDU end
struct ZImage      <: AbstractHDU end
struct ZTable      <: AbstractHDU end

#  Conforming HDU Extensions
struct Conform     <: AbstractHDU end
struct IUEImage    <: AbstractHDU end
struct A3DTable    <: AbstractHDU end
struct Foreign     <: AbstractHDU end
struct Dump        <: AbstractHDU end

Cards = Union{Vector{Card}, Vector{Card{<:Any}}}

#   HDU type
"""
    HDU{T}(cards, data)

Create an header-data unit type, where T is an AbstractHDU.
"""
struct HDU{S<:AbstractHDU}
    "The vector of cards."
    cards::Cards
    "The data, either an AbstractArray, Tuple, NamedTuple, or Nothing"
    data::Union{AbstractArray, Tuple, NamedTuple, Nothing}
end

abstract type AbstractField end

"""
    DataFormat(type, leng, shape, param, group, heap)

The generic data format descriptor for HDUs.
"""
struct DataFormat
    "The type of the array element."
    type::Type
    "The number of elements."
    leng::Integer
    "The shape of the array."
    shape::Tuple
    "The number of parameters."
    param::Integer
    "The number of groups."
    group::Integer
    "The offset of the heap in bytes."
    heap::Integer
end

const BLOCKLEN  = 2880
const BYTELEN   = 8
const BITS2TYPE = Dict(8 => UInt8, 16 => Int16, 32 => Int32, 64 => Int64,
    -32 => Float32, -64 => Float64)
const TYPE2BITS = Dict(UInt8 => 8, Int16 => 16, Int32 => 32, Int64 => 64,
    Float32 => -32, Float64 => -64)

const MISSTYPE = (UInt8, Int16, Int32, Int64)
const TEMPTYPE = Dict(-2^7 => Int16, 2^15 => UInt32, UInt32(2)^31 => UInt64,
    UInt64(2)^63 => UInt128)
const OUTTYPE  = Dict(
    UInt8 => Float32, Int16 => Float32, Int32 => Float64, Int64 => Float64,
    Float32 => Float32, Float64 => Float64)
    
    #  Combine XTENSION values in card.jl and hdu.jl
const XTENSIONTYPE = Dict("IMAGE   " => Image, "TABLE   " => Table,
    "BINTABLE" => Bintable)

const MANDATORYKEYS = (
    #  Mandatory keys, except THEAP (see Table C.1)
    "END", "SIMPLE", "XTENSION", "BITPIX", "NAXIS", "GROUPS", "PCOUNT",
    "GCOUNT", "THEAP", "TFIELDS", "TFORM", "TBCOL", "ZIMAGE", "ZTABLE",
    "ZBITPIX", "ZNAXIS", "ZPCOUNT", "ZFORM", "ZCTYP", "ZCMPTYPE", "ZTILELEN")

const RESERVEDKEYS = (
    #  General keys
    "DATE", "DATE-OBS", "ORIGIN", "AUTHOR", "REFERENC",
    "OBJECT", "OBSERVER", "INHERIT", "CHECKSUM", "DATASUM", "EXTNAME",
    "EXTVER", "EXTLEVEL", "EQUINOX", "EPOCH", "BLOCKED", "EXTEND", "TELESCOP",
    "INSTRUME",
    #  Random field keys
    "PTYPE", "PSCAL", "PZERO",
    #  Image field keys
    "BSCALE", "BZERO", "BUNIT", "BLANK", "DATAMAX", "DATAMIN",
    #  Table field keys
    "TFIELDS", "TFORM", "TBCOL", "TSCAL", "TZERO", "TNULL", "TTYPE", "TUNIT",
    "TDISP", "TDMAX", "TDMIN", "TLMAX", "TLMIN",
    #  Bintable field keys, except THEAP
    "TFIELDS", "TFORM", "TSCAL", "TSCAL", "TZERO", "TNULL", "TTYPE", "TUNIT",
    "TDISP", "TDIM", "TDMAX", "TDMIN", "TLMAX", "TLMIN",
    #  ZImage field keys
    "ZTILE", "ZNAME", "ZVAL", "ZMASKCMP", "ZQUANTIZ", "ZDITHER0", "ZSIMPLE",
    "ZEXTEND", "ZBLOCKED", "ZTENSION", "ZPCOUNT", "ZGCOUNT", "ZHECKSUM",
    "ZDATASUM",
    #  ZTable field keys
    "FZTILELN", "FZALGOR", "FZALG", "ZTHEAP", "ZHECKSUM", "ZDATASUM")

#  Check for header missing END card

"""
    HDU([data, [cards]]; <keywords>)
    HDU(cards; <keywords>)
    HDU(type, nothing, [cards]; <keywords>)
    HDU(type, data, [cards]; <keywords>)

Create an header-data unit described by data and cards of type AbstractHDU.

The HDU function tries to determine the HDU type based on the data and cards.
If only data is provided, then an array is interpreted as a Primary HDU and a
Tuple or NamedTuple as a BinaryTable. If mandatory cards are provided, then
they are used to determine the HDU type. Otherwise, the HDU type must be
specified.

HDU types are: Primary, Random, Image, Table, Bintable, and Conform.

# arguments

- `data::U=nothing`: the binary or ASCII data, where U<:Union{AbstractArray,
    Tuple, NamedTuple, Nothing}
- `cards::U=nothing`: the list of cards, where U<:Union{Card, Vector{Card}, Nothing}

# Keywords

- `record::Bool=false`: structure the data as a list of records
- `scale::Bool=true`: apply the scale and zero keywords to the data
- `append::Bool=false`: append CONTINUE cards for long strings (>68 characters)
- `fixed::Bool=true`: create fixed format cards
- `slash::Integer=32`: character index of the comment separator (/)
- `lpad::Integer=1`: number of spaces before the comment separator
- `rpad::Integer=1`: number of spaces after the comment separator
- `truncate::Bool=true`: truncate the comment string at the end of the card
"""
function HDU(data::D=nothing, cards::C=nothing; record::B=false,
    scale::B=true, append::B=false, fixed::B=true, slash::I=32, lpad::I=1,
    rpad::I=1, truncate::B=true) where
    {C<:Union{Nothing, Card, Cards, Vector{Card{T}}} where T<:AbstractCardType,
    D<:Union{Nothing, AbstractArray, Tuple, NamedTuple}, B<:Bool, I<:Integer}

    kwds = (;
        #  data formatting options
        record=record, scale=scale,
        #  card formatting options
        append=append, fixed=fixed, slash=slash, lpad=lpad, rpad=rpad,
        truncate=truncate)

    kards = isnothing(cards) ? Card[] : copy(cards)

    #  Remove END card. END card is implied. It will be appended on write.
    if !isnothing(kards) popat!(kards, "END") end

    #  Detect HDU type from either data or cards
    type = typeofhdu(data, get_reserved_keys(kards)[1])
    HDU(type, data, kards; kwds...)
end

HDU(cards::Cards; kwds...) = HDU(nothing, cards; kwds...)

function HDU(type::Type, ::Nothing=nothing, cards::C=nothing; kwds...) where
    C<:Union{Card, Vector{Card}, Vector{Card{<:Any}}, Nothing}

    kwds  = isnothing(kwds) ? (; ) : kwds
    kards = isnothing(cards) ? Card[] : copy(cards)

    #  Remove END card. END card is implied. It will be appended on write.
    if !isnothing(kards) popat!(kards, "END") end

    #  Create dictionaries of mandatory and reserved keywords
    mankeys, reskeys = get_reserved_keys(kards)

    format = DataFormat(type, nothing, mankeys)
    kards  = verify!(type, kards, format, mankeys)
    fields = FieldFormat(type, format, reskeys, nothing)
    kards  = create_cards!(type, format, fields, kards; kwds...)
    data   = create_data(type, format, fields; kwds...)

    HDU{type}(kards, data)
end

function HDU(type::Type, data::AbstractArray, cards::C=nothing; kwds...) where
    C<:Union{Card, Vector{Card}, Vector{Card{<:Any}}, Nothing}

    kwds  = isnothing(kwds) ? (; ) : kwds
    kards = isnothing(cards) ? Card[] : copy(cards)

    #  Remove END card. END card is implied. It will be appended on write.
    if !isnothing(kards) popat!(kards, "END") end

    #  Create dictionaries of mandatory and reserved keywords
    mankeys, reskeys = get_reserved_keys(kards)

    format = DataFormat(type, data, mankeys)
    kards  = verify!(type, kards, format, mankeys)
    fields = FieldFormat(type, format, reskeys, data)
    kards  = create_cards!(type, format, fields, kards; kwds...)
    if eltype(data) <: Tuple
        data = [(; [Symbol(fields[j].name) => data[k][j]
            for j=1:format.param]..., data = data[k][end]) for k=1:format.group]
    end

    HDU{type}(kards, data)
end

function HDU(type::Type, data::U, cards::C=nothing; kwds...) where
    {U<:Union{Tuple, NamedTuple},
    C<:Union{Card, Vector{Card}, Vector{Card{<:Any}}, Nothing}}

    kwds  = isnothing(kwds) ? (; ) : kwds
    kards = isnothing(cards) ? Card[] : copy(cards)

    #  Remove END card. END card is implied. It will be appended on write.
    if !isnothing(kards) popat!(kards, "END") end

    #  Create dictionaries of mandatory and reserved keywords
    mankeys, reskeys = get_reserved_keys(kards)

    format = DataFormat(type, data, mankeys)
    kards  = verify!(type, kards, format, mankeys)
    fields = FieldFormat(type, format, reskeys, data; kwds...)
    kards  = create_cards!(type, format, fields, kards; kwds...)
    if typeof(data) <: Tuple
        data = (; [Symbol(fields[j].name) => data[j] for j=1:format.param]...,
            data = data[end])
    end

    HDU{type}(kards, data)
end

"""
    info(hdu::HDU)

Briefly describe the header-data unit.
"""
function info(hdu::HDU)
    cards = hdu.cards
    N = cards["NAXIS"]
    typ = rpad(typeofhdu(hdu),8)
    crd = lpad(length(cards),6)
    siz = join([string(cards["NAXIS$j"])
        for j=(typeofhdu(hdu) == Random ? 2 : 1):N], " × ")
    eltype = lpad(datatype(cards), 8)
    println("$typ  $crd  $eltype   $siz")
end

function Base.show(io::IO, hdu::HDU)
    show(io, hdu.cards)
    print(io, "\n")
    show(io, hdu.data)
end

"""
    read(io, type; <keywords>)

Read the specified HDU type from a file.
"""
function read(io::IO, ::Type{HDU}; kwds...)::HDU
    #  Read cards
    cards, mankeys, reskeys = read(io, Card)

    #  Read data
    type   = typeofhdu(mankeys)
    format = DataFormat(type, nothing, mankeys)
    cards  = verify!(type, cards, format, mankeys)
    fields = FieldFormat(type, format, reskeys, nothing)
    data   = read(io, type, format, fields; kwds...)

    HDU{type}(cards, data)
end

"""
    write(io, hdu; <keywords>)

Write the specified HDU type to a file.
"""
function write(io::IO, hdu::HDU{<:AbstractHDU}; kwds...)

    cards  = hdu.cards
    mankeys, reskeys = get_reserved_keys(cards)

    type   = typeofhdu(hdu)
    format = DataFormat(type, nothing, mankeys)
    cards  = verify!(type, cards, format, mankeys)
    fields = FieldFormat(type, format, reskeys, nothing)
    #  Write cards
    write(io, cards)
    #  Write data
    write(io, type, hdu.data, format, fields; kwds...)
end

function read(io::IO, ::Type{Card})
    #  Read cards
    cards = Card{<:Any}[]
    mankeys = Dict{AbstractString, ValueType}()
    reskeys = Dict{AbstractString, ValueType}()
    N, M = BLOCKLEN÷CARDLENGTH, CARDLENGTH

    lastblok = false
    block = Base.read(io, BLOCKLEN)
    while !lastblok
        for j=1:N
            card = parse(Card, String(block[M*(j-1)+1:M*j]))
            if any(occursin.(MANDATORYKEYS, card.key))
                mankeys[card.key] = card.value
            end
            if any(occursin.(RESERVEDKEYS, card.key))
                reskeys[card.key] = card.value
            end
            if typename(card) == End
                lastblok = true
                break
            end
            push!(cards, card)
        end
        if lastblok
            break
        end
        block = Base.read(io, BLOCKLEN)
    end
    (cards, mankeys, reskeys)
end

function write(io::IO, cards::Cards)
    #  Write header cards
    for card in cards
        Base.write(io, repr(card))
    end
    #  Append END card
    Base.write(io, repr(Card("END")))
    M, ncards = length(cards)+1, BLOCKLEN÷CARDLENGTH
    N = ncards*div(M, ncards, RoundUp)
    #  Pad header with blank cards
    for j = M+1:N
        Base.write(io, repr(Card()))
    end
end

function get_reserved_keys(cards::Cards)
    mankeys = Dict{AbstractString, ValueType}()
    reskeys = Dict{AbstractString, ValueType}()
    for card in cards
        if any(occursin.(MANDATORYKEYS, card.key))
            mankeys[card.key] = card.value
        end
        if any(occursin.(RESERVEDKEYS, card.key))
            reskeys[card.key] = card.value
        end
    end
    (mankeys, reskeys)
end

####    Utility functions
typeofhdu(::HDU{T}) where T = T

"""
    typeofhdu(data)

Determine the HDU type based on the data structure.
"""
function typeofhdu(data::U) where
    U<:Union{AbstractArray, Tuple, NamedTuple, Nothing}

    if !isnothing(data)
        if eltype(data) <: Real
            type = Primary
        elseif eltype(data) <: AbstractString
            type = Table
        elseif typeof(data) <: Union{Tuple, NamedTuple}
            type = typeof(data[end]) <: AbstractArray &&
                ndims(data[end]) >= 2 ? Random : Bintable
        elseif basetype(eltype(data)) in (Tuple, NamedTuple)
            type = typeof(data[1][end]) <: AbstractArray &&
                ndims(data[1][end]) >= 2 ? Random : Bintable
        else
            type = Conform
        end
    else
        type = nothing
    end
    type
end

"""
    typeofhdu(dict)

Determine the HDU type based on the list of mandatory keywords.
"""
function typeofhdu(mankeys::Dict{S, V}) where {S<:AbstractString, V<:ValueType}
    #  Determine HDU type from mandatory keys
    exval = get(mankeys, "XTENSION", nothing)
    if !isnothing(exval)
        type = get(XTENSIONTYPE, exval, Conform)
        if type == Bintable
            if get(mankeys, "ZIMAGE", false)
                type = ZImage
            elseif get(mankeys, "ZTABLE", false)
                type = ZTable
            end
        end
    elseif get(mankeys, "SIMPLE", false) == true
        if get(mankeys, "GROUPS", false) == true &&
            haskey(mankeys, "NAXIS1") && mankeys["NAXIS1"] == 0
            type = Random
        else
            type = Primary
        end
    else
        error("Unknown HDU")
    end
    type
end

"""
    typeofhdu(data, dict)

Determine the HDU type based on the data and list of mandatory keywords.
"""
function typeofhdu(data::U, mankeys::Dict{S, V}) where
    {U<:Union{AbstractArray, Tuple, NamedTuple, Nothing},
    S<:AbstractString, V<:ValueType}

    type = Primary
    if !isnothing(data)
        type = typeofhdu(data)
    end
    if !isempty(mankeys)
        type = typeofhdu(mankeys)
    end
    type
end
#=
function compressed(type::Type{<:AbstractHDU}, mankeys::Dict{S, V}) where
    {S<:AbstractString, V<:ValueType}
    if type == Bintable
        if get(mankeys, "ZIMAGE", false)
            type = ZImage
        elseif get(mankeys, "ZTABLE", false)
            type = ZTable
        end
    end
    type
end
=#
basetype(T) = Base.typename(T).wrapper

####    Array-like Functions

datatype(data::AbstractArray) = eltype(data)
datadims(data::AbstractArray) = ndims(data)
datasize(data::AbstractArray) = size(data)
databytes(data::AbstractArray) = eltype(data)*length(data)
datalength(data::AbstractArray) = length(data)
function recordlength(data::U) where U<:Union{Tuple, NamedTuple}
    sum([typeof(f) <: BitVector ? sizeof(f)÷8 : sizeof(f) for f in data])
end

datadims(mankeys::Dict) = mankeys["NAXIS"]

function datasize(mankeys::Dict, start::Integer=1)
    #  Determine the shape of the array
    N = get(mankeys, "NAXIS", 0)
    N > 0 ? Tuple(mankeys["NAXIS$j"] for j=start:N) : ()
end

function datalength(mankeys::Dict, start::Integer=1)
    #   Calculate the number of elements in the array
    N = get(mankeys, "NAXIS", 0)
    G, P = get(mankeys, "GCOUNT", 1), get(mankeys, "PCOUNT", 0)
    N > 0 ? G * (P + prod(datasize(mankeys, start))) : 0
end

datatype(cards::Cards) = BITS2TYPE[get(cards, "BITPIX", 32)]
datadims(cards::Cards) = get(cards, "NAXIS", 0)

function datasize(cards::Cards, start::Integer=1)
    #  Determine the shape of the array
    N = datadims(cards)
    N > 0 ? Tuple(cards["NAXIS$j"] for j=start:N) : ()
end

function databytes(cards::Cards, start::Integer=1)
    #  Calculate the number of bytes of data
    N, G, P = cards["NAXIS"], get(cards, "GCOUNT", 1), get(cards, "PCOUNT", 0)
    N > 0 ? sizeof(datatype(cards)) * G * (P + prod(datasize(cards, start))) : 0
end

function datalength(cards::Cards, start::Integer=1)
    #  Calculate the number of elements in the array
    N, G, P = cards["NAXIS"], get(cards, "GCOUNT", 1), get(cards, "PCOUNT", 0)
    N > 0 ? G * (P + prod(datasize(cards, start))) : 0
end

####    Generic IO Functions

function padblock(io::IO, format::DataFormat, pad::UInt8=0x00)
    #  Pad remaining data block to BLOCKLEN length (2880 bytes)
    N = format.leng*sizeof(format.type)
    nbloks = div(N, BLOCKLEN, RoundUp)
    Base.write(io, fill(pad, nbloks*BLOCKLEN-N))
end

####    Reserved Keywords
#=
function parse_general(cards::Cards)
    date = get(cards, "DATE", missing)
    orign = get(cards, "ORIGIN", missing)
    xtend = get(cards, "EXTEND", missing)
    blokd = get(cards, "BLOCKED", missing)
end

function parse_observatory(cards::Cards)
    datobs = get(cards, "DATE-OBS", missing)
    # datxxx = get(cards, "DATExxxx", missing)
    telscp = get(cards, "TELESCOP", missing)
    instru = get(cards, "INSTRUME", missing)
    obsrvr = get(cards, "OBSERVER", missing)
    object = get(cards, "OBJECT", missing)
end

function parse_biblio(cards::Cards)
    author = get(cards, "AUTHOR", missing)
    refern = get(cards, "REFERENC", missing)
end

function parse_extension(cards::Cards)
    xname  = get(cards, "EXTNAME", missing)
    xver   = get(cards, "EXTVER", missing)
    xlevel = get(cards, "EXTLEVEL", missing)
    nherit = get(cards, "INHERIT", missing)
end

function parse_checksums(card::Cards)
    datsum = get(cards, "DATASUM", missing)
    chksum = get(cards, "CHECKSUM", missing)
end

function parse_wcs(cards::Cards)
end
=#

####    Dictionary-like Key functions

"""
    haskey(cards, key)

Check for keyword in list of cards.
"""
function Base.haskey(cards::Cards, key::AbstractString)
    for card in cards
        if card.key == uppercase(key)
            return true
        end
    end
    false
end

"""
    getindex(cards, key)

Get the keyword value in a list of cards.
"""
function Base.getindex(cards::Cards, key::AbstractString)
    for card in cards
        if card.key == uppercase(key)
            return card.value
        end
    end
    throw(KeyError(key))
end

"""
    get(cards, key, default=nothing)

Get the keyword value in a list of cards. Return default if not found.
"""
function Base.get(cards::Cards, key::AbstractString, default=nothing)
    value = default
    for card in cards
        if card.key == uppercase(key)
            value = card.value
            break
        end
    end
    value
end

function Base.get(cards::Cards, keys::Tuple, defaults::Tuple)
    values = [defaults...]
    for (j, key) in enumerate(keys)
        for card in cards
            if card.key == uppercase(key)
                values[j] = card.value
            end
        end
    end
    (values...,)
end

function Base.setindex!(cards::Cards, value::ValueType, key::AbstractString)
    for (j, card) in enumerate(cards)
        if card.key == uppercase(key)
            cards[j] = setvalue!(card, value)
            return
        end
    end
    throw(KeyError(key))    
end

function Base.findfirst(key::AbstractString, cards::Cards)
    for (j, card) in enumerate(cards)
        if card.key == uppercase(key)
            return j
        end
    end
    nothing
end

function Base.popat!(cards::Cards, key::AbstractString, default=Card())
    card = try
        Base.popat!(cards, Base.findfirst(key, cards))
    catch
        default
    end
    card
end  

#=
function Base.get(cards::Cards, key::T, default; find=:first) where T<:AbstractString
    value = find == :all ? [] : nothing
    for card in cards
        if card.key == uppercase(key)
            if find in [:all, :full]
                push!(value, card.value)
            else
            value = card.value; break
            elseif find == :all
                push!(value, card.value)
            elseif find == :full
            end
        end
    end
    isnothing(value) || isempty(value) ? default : value
end
=#
