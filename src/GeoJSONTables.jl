module GeoJSONTables

import JSON3, Tables
using GeometryBasics
# using GeometryBasics.StructArrays

struct Feature{T, Names, Types}
    geometry::T
    properties::NamedTuple{Names, Types}
end

# TODO use a StructArray here instead
struct FeatureCollection
    features::Vector{<:Feature}
end

function read(source)
    fc = JSON3.read(source)
    jsonfeatures = get(fc, :features, nothing)
    if get(fc, :type, nothing) == "FeatureCollection" && jsonfeatures isa JSON3.Array
        features = [Feature(geometry(f.geometry),
                    (; zip(keys(f.properties), values(f.properties))...))
                    for f in jsonfeatures]
        FeatureCollection(features)
    else
        throw(ArgumentError("input source is not a GeoJSON FeatureCollection"))
    end
end

Tables.istable(::Type{<:FeatureCollection}) = true
Tables.rowaccess(::Type{<:FeatureCollection}) = true
Tables.rows(fc::FeatureCollection) = fc

Base.IteratorSize(::Type{<:FeatureCollection}) = Base.HasLength()
Base.length(fc::FeatureCollection) = length(features(fc))
Base.IteratorEltype(::Type{<:FeatureCollection}) = Base.HasEltype()

# read only AbstractVector
Base.size(fc::FeatureCollection) = size(features(fc))
Base.getindex(fc::FeatureCollection, i) = features(fc)[i]
Base.IndexStyle(::Type{<:FeatureCollection}) = IndexLinear()

miss(x) = ifelse(x === nothing, missing, x)

# these features always have type="Feature", so exclude that
# the keys in properties are added here for direct access
Base.propertynames(f::Feature) = keys(properties(f))

"Get the FeatureCollection's features as a vector"
features(f::FeatureCollection) = getfield(f, :features)

"Get the feature's geometry as a GeometryBasics geometry type"
geometry(f::Feature) = getfield(f, :geometry)

"Get the feature's properties as a NamedTuple"
properties(f::Feature) = getfield(f, :properties)

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
    st = iterate(features(fc))
    st === nothing && return nothing
    val, state = st
    return val, state
end

@inline function Base.iterate(fc::FeatureCollection, st)
    st = iterate(features(fc), st)
    st === nothing && return nothing
    val, state = st
    return val, state
end

Base.show(io::IO, fc::FeatureCollection) = println(io, "FeatureCollection with $(length(fc)) Features")
function Base.show(io::IO, f::Feature)
    geomtype = nameof(typeof(geometry(f)))
    println(io, "Feature with geometry type $geomtype and properties $(propertynames(f))")
end
Base.show(io::IO, ::MIME"text/plain", fc::FeatureCollection) = show(io, fc)
Base.show(io::IO, ::MIME"text/plain", f::Feature) = show(io, f)

"""
Take the JSON3 representation of a GeoJSON geometry
and convert it to the corresponding GeometryBasics geometry.
"""
function geometry end

geometry(::Nothing) = missing

function geometry(g::JSON3.Object)
    t = g.type
    if t == "Point"
        return geometry(Point, g.coordinates)
    elseif t == "LineString"
        return geometry(LineString, g.coordinates)
    elseif t == "Polygon"
        return geometry(Polygon, g.coordinates)
    elseif t == "MultiPoint"
        return geometry(MultiPoint, g.coordinates)
    elseif t == "MultiLineString"
        return geometry(MultiLineString, g.coordinates)
    elseif t == "MultiPolygon"
        return geometry(MultiPolygon, g.coordinates)
    elseif t == "GeometryCollection"
        return [geometry(geom) for geom in g.geometries]
    else
        throw(ArgumentError(string("Unknown geometry type ", t)))
    end
end

function geometry(::Type{Point}, g::JSON3.Array)
    return Point{2, Float64}(g)
end

function geometry(::Type{LineString}, g::JSON3.Array)
    return LineString([Point{2, Float64}(p) for p in g], 1)
end

function geometry(::Type{Polygon}, g::JSON3.Array)
    # TODO introduce LinearRing type in GeometryBasics?
    nring = length(g)
    exterior = LineString([Point{2, Float64}(p) for p in g[1]], 1)
    if nring == 1  # only exterior
        return Polygon(exterior)
    else  # exterior and interior(s)
        interiors = Vector{typeof(exterior)}(undef, nring)
        for i in 2:nring
            interiors[i-1] = LineString([Point{2, Float64}(p) for p in g[i]], 1)
        end
        return Polygon(exterior, interiors)
    end
end

function geometry(::Type{MultiPoint}, g::JSON3.Array)
    return MultiPoint([geometry(Point, x) for x in g])
end

function geometry(::Type{MultiLineString}, g::JSON3.Array)
    return MultiLineString([geometry(LineString, x) for x in g])
end

function geometry(::Type{MultiPolygon}, g::JSON3.Array)
    return MultiPolygon([geometry(Polygon, x) for x in g])
end

include("SA_test.jl")

end # module
