module GeoJSONTables

import JSON3, Tables
using GeometryBasics
using GeometryBasics.StructArrays

struct Feature{T, Names, Types}
    geometry::T
    properties::NamedTuple{Names, Types}
end

Feature(x; kwargs...) = Feature(x, values(kwargs))

function read(source)
    fc = JSON3.read(source)
    jsonfeatures = get(fc, :features, nothing)
    if get(fc, :type, nothing) == "FeatureCollection" && jsonfeatures isa JSON3.Array
        features = [Feature(geometry(f.geometry),
                    (; zip(keys(f.properties), values(f.properties))...))
                    for f in jsonfeatures]
        iter = (i for i in features)
        maketable(iter)
    else
        throw(ArgumentError("input source is not a GeoJSON FeatureCollection"))
    end
end

getnamestypes(::Type{Feature{T, Names, Types}}) where {T, Names, Types} = (T, Names, Types)

function StructArrays.staticschema(::Type{F}) where {F<:Feature}
    T, names, types = getnamestypes(F)
    NamedTuple{(:geometry, names...), Base.tuple_type_cons(T, types)}
end

 function StructArrays.createinstance(::Type{F}, x, args...) where {F<:Feature}
     T , names, types = getnamestypes(F)
     Feature(x, NamedTuple{names, types}(args))
 end

maketable(iter) = maketable(Tables.columntable(iter)::NamedTuple)
maketable(cols::NamedTuple) = maketable(first(cols), Base.tail(cols)) # you could also compute the types here with `Base.tuple_type_tail` and `Base.tuple_type_head`

function maketable(geometry, properties::NamedTuple{names, types}) where {names, types}
    F = Feature{eltype(geometry), names, StructArrays.eltypes(types)}
    return StructArray{F}(; geometry=geometry, properties...)
end

miss(x) = ifelse(x === nothing, missing, x)

# these features always have type="Feature", so exclude that
# the keys in properties are added here for direct access
Base.propertynames(f::Feature) = (:geometry, keys(properties(f))...)

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
Base.getproperty(f::Feature, s::Symbol) = s == :geometry ? getfield(f, 1) : getproperty(getfield(f, 2), s)

function Base.show(io::IO, f::Feature)
    geomtype = nameof(typeof(geometry(f)))
    println(io, "Feature with geometry type $geomtype and properties $(propertynames(f))")
end
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
end # module
