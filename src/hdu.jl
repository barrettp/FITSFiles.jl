####    HDU type    ####

abstract type AbstractHDU end

#  Primary HDU
struct Primary     <: AbstractHDU end
struct Random      <: AbstractHDU end

#  Standard HDU Extensions
struct Image       <: AbstractHDU end
struct Table       <: AbstractHDU end
struct Bintable    <: AbstractHDU end
struct ZImage      <: AbstractHDU end
struct ZTable      <: AbstractHDU end

#  Conforming HDU Extensions
struct IUEImage    <: AbstractHDU end
struct A3DTable    <: AbstractHDU end
struct Foreign     <: AbstractHDU end
struct Dump        <: AbstractHDU end

const BLOCKLEN  = 2880
const BYTELEN   = 8
const BITS2TYPE = Dict(
    8 => UInt8, 16 => Int16, 32 => Int32, 64 => Int64, -32 => Float32, -64 => Float64)
const TYPE2BITS = Dict(
    UInt8 => 8, Int16 => 16, Int32 => 32, Int64 => 64, Float32 => -32, Float64 => -64)

const BLANKTYPE = (UInt8, Int16, Int32, Int64)
const TEMPTYPE = Dict(-2^7 => Int16, 2^15 => UInt32, UInt32(2)^31 => UInt64,
    UInt64(2)^63 => UInt128)
const OUTTYPE  = Dict(UInt8 => Float32, Int16 => Float32, Int32 => Float64, Int64 => Float64)
    
    #  Combine XTENSION values in card.jl and hdu.jl
const XTENSIONTYPE = Dict("IMAGE   " => Image, "TABLE   " => Table, "BINTABLE" => Bintable)


#=
#  Data Descriptor
struct DataDesc{S<:AbstractHDU}
    dimen::Vector{UInt}
    type::Type
    heap::UInt  = 0
    group::UInt = 1
    field::Vector{NamedTuple} = (;)
    misc::Vector{NamedTuple}   = (;)
end

function DataDesc(header::Vector{Card})
    type  = TYPE2BITS[header["BITPIX"]]
    dimen = [header["NAXIS$j"] for j = 1:header["NAXIS"]]
    heap  = get(header, "PCOUNT", 0)
    group = get(header, "GCOUNT", 1)
    field = (;)
    misc  = (;)
    DataDesc{typeofhdu(header)}(dimen, type, heap, group, field, misc)
end
=#

#   HDU type
struct HDU{S<:AbstractHDU}
    header::Vector{Card}
    data::AbstractArray
end

"""

"""
function HDU(cards::C=Card[], data::D=zeros(Int32,()); simple::B=true, append::B=false,
    fixed::B=true, slash::I=32, lpad::I=1, rpad::I=1, truncate::B=true, scale::B=true) where
    {C<:Union{Card, Vector{Card}, Vector{Card{T}}} where T<:AbstractCardType,
    D<:AbstractArray, B<:Bool, I<:Integer}

    kwds = (;simple=simple, append=append, fixed=fixed, slash=slash, lpad=lpad, rpad=rpad,
            truncate=truncate, scale=scale)

    cards = Vector{Card}(typeof(cards)<:Card{T} where T<:AbstractCardType ? [cards] : cards)
    # println(cards)
    type = typeofhdu(cards, simple)

    #  Add cards to header
    meta = create_header(type, cards, data, kwds)

    #  Verify mandatory key cards
    # verify!(type, meta)
    
    HDU{type}(meta, data)
end

function read(io::IO, ::Type{HDU}; kwds...)::HDU
    #  Read header cards
    cards, cards_ = Card[], Card[]
    while !hasEnd(cards_)
        cards_ = Card[parse(Card, String(Base.read(io, CARDLENGTH)))
                      for j = 1:BLOCKLEN÷CARDLENGTH]
        append!(cards, cards_[1:(hasEnd(cards_) ? findfirst("END", cards_)-1 : end)])
    end

    #  Read data
    data = read(io, typeofhdu(cards), cards; kwds...)
    HDU(cards, data)
end

function write(io::IO, hdu::HDU)
    cards = hdu.header
    #  Write header cards
    for card in cards write(io, card.image) end
    ncards = BLOCKLEN÷CARDLENGTH
    M, N = length(cards)+1, ncards*div(length(cards), ncards, RoundUp)
    #  Pad header with blank cards
    for j = M:N write(io, Card()) end

    #  Write data
    write(io, typeofhdu(hdu), cards, hdu.data)
end

####    Header card functions

function hasEnd(cards::Vector{Card})
    for card in cards
        if typename(card) == End
            return true
        end
    end
    false
end

####    Utility functions

function hasdata(cards::Vector{Card})
    haskey(cards, "BITPIX") && haskey(cards, "NAXIS") ?
        (&)([haskey(cards, "NAXIS"*string(j)) for j = 1:cards["NAXIS"]]...) : false
end

typeofhdu(::HDU{T}) where T = T

function typeofhdu(cards::Vector{Card}, simple)
    if (haskey(cards, "SIMPLE") && cards["SIMPLE"] == true)
        if (haskey(cards, "NAXIS1") && cards["NAXIS1"] == 0) &&
            (haskey(cards, "GROUPS") && cards["GROUPS"] == true)
            type = Random
        else
            type = Primary
        end
    elseif haskey(cards, "XTENSION")
        try
            type = XTENSIONTYPE[cards["XTENSION"]]
        catch e
            error("Unknown HDU type")
        end
    elseif get(cards, "ZIMAGE  ", false) 
        type = ZImage
    elseif get(cards, "ZTABLE  ", false)
        type = ZTable
    elseif simple == false
        type = Image
    else
        type = Primary
    end
    type
end

function typeofhdu(data::AbstractArray, simple=true)
    if length(data) == 0 || eltype(data) <: Real
        type = simple == true ? Primary : Image
    elseif eltype(data) <: AbstractString
        type = Table
    elseif basename(eltype(data)) == Tuple
        type = Bintable
    else
        error("Unknown HDU type")
    end
    type
end

datatype(cards::Vector{Card}) = BITS2TYPE[cards["BITPIX"]]
datashape(cards::Vector{Card}) = [cards["NAXIS$j"] for j=1:cards["NAXIS"]]

function datalen(cards::Vector{Card})
    cards["NAXIS"] > 0 ? abs(cards["BITPIX"])÷BYTELEN * get(cards, "GCOUNT", 1) *
        (get(cards, "PCOUNT", 0) + prod(datashape(cards))) : 0
end

####    Dictionary-like Key functions

function Base.haskey(cards::Vector{Card}, key::AbstractString)
    for card in cards
        if card.key == uppercase(key)
            return true
        end
    end
    false
end

function Base.getindex(cards::Vector{Card}, key::AbstractString)
    for card in cards
        if card.key == uppercase(key)
            return card.value
            break
        end
    end
    throw(KeyError(key))
end

function Base.get(cards::Vector{Card}, key::AbstractString, default=missing)
    value = default
    for card in cards
        if card.key == uppercase(key)
            value = card.value
            break
        end
    end
    value
end

function Base.get(cards::Vector{Card}, keys::Tuple, defaults::Tuple)
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

function Base.findfirst(key::AbstractString, cards::Vector{Card})
    for (j, card) in enumerate(cards)
        if card.key == uppercase(key)
            return j
        end
    end
    nothing
end

function Base.popat!(cards::Vector{Card}, key::AbstractString, default=Card())
    card = try
        Base.popat!(cards, Base.findfirst(key, cards))
    catch
        default
    end
    card
end  

#=
function Base.get(cards::Vector{Card}, key::T, default; find=:first) where T<:AbstractString
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
