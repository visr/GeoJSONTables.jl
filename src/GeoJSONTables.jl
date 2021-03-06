module GeoJSONTables

import JSON3, Tables, GeoInterface

struct FeatureCollection{T} <: AbstractVector{eltype(T)}
    json::T
end

function read(source)
    fc = JSON3.read(source)
    features = get(fc, :features, nothing)
    if get(fc, :type, nothing) == "FeatureCollection" && features isa JSON3.Array
        FeatureCollection{typeof(features)}(features)
    else
        throw(ArgumentError("input source is not a GeoJSON FeatureCollection"))
    end
end

Tables.istable(::Type{<:FeatureCollection}) = true
Tables.rowaccess(::Type{<:FeatureCollection}) = true
Tables.rows(fc::FeatureCollection) = fc

Base.IteratorSize(::Type{<:FeatureCollection}) = Base.HasLength()
Base.length(fc::FeatureCollection) = length(json(fc))
Base.IteratorEltype(::Type{<:FeatureCollection}) = Base.HasEltype()

# read only AbstractVector
Base.size(fc::FeatureCollection) = size(json(fc))
Base.getindex(fc::FeatureCollection, i) = Feature(json(fc)[i])
Base.IndexStyle(::Type{<:FeatureCollection}) = IndexLinear()

miss(x) = ifelse(x === nothing, missing, x)

struct Feature{T}
    json::T
end

# these features always have type="Feature", so exclude that
# the keys in properties are added here for direct access
Base.propertynames(f::Feature) = keys(properties(f))

"Access the properties JSON3.Object of a Feature"
properties(f::Feature) = json(f).properties
"Access the JSON3.Object that represents the Feature"
json(f::Feature) = getfield(f, :json)
"Access the JSON3.Array that represents the FeatureCollection"
json(f::FeatureCollection) = getfield(f, :json)
"Access the JSON3.Object that represents the Feature's geometry"
geometry(f::Feature) = json(f).geometry

"""
Get a specific property of the Feature

Returns missing for null/nothing or not present, to work nicely with
properties that are not defined for every feature. If it is a table,
it should in some sense be defined.
"""
function Base.getproperty(f::Feature, nm::Symbol)
    props = properties(f)
    val = get(props, nm, missing)
    miss(val)
end

@inline function Base.iterate(fc::FeatureCollection)
    st = iterate(json(fc))
    st === nothing && return nothing
    val, state = st
    return Feature(val), state
end

@inline function Base.iterate(fc::FeatureCollection, st)
    st = iterate(json(fc), st)
    st === nothing && return nothing
    val, state = st
    return Feature(val), state
end

Base.show(io::IO, fc::FeatureCollection) = println(io, "FeatureCollection with $(length(fc)) Features")
function Base.show(io::IO, f::Feature)
    println(io, "Feature with geometry type $(geometry(f).type) and properties $(propertynames(f))")
end
Base.show(io::IO, ::MIME"text/plain", fc::FeatureCollection) = show(io, fc)
Base.show(io::IO, ::MIME"text/plain", f::Feature) = show(io, f)

include("geointerface.jl")

end # module
