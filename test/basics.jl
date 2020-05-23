using Base.Iterators
using GeoJSONTables
using JSON3
import GeoInterface
using Tables
using Test
using BenchmarkTools
using GeometryBasics
using GeometryBasics.StructArrays

struct GeometryCollection end

function basicgeometry(f::GeoJSONTables.Feature)
    object = GeoJSONTables.geometry(f)
    return basicgeometry(object)
end

function basicgeometry(g::JSON3.Object)
    t = g.type
    if t == "Point"
        return basicgeometry(Point, g.coordinates)
    elseif t == "LineString"
        return basicgeometry(LineString, g.coordinates)
    elseif t == "Polygon"
        return basicgeometry(Polygon, g.coordinates)
    elseif t == "MultiPoint"
        return basicgeometry(MultiPoint, g.coordinates)
    elseif t == "MultiLineString"
        return basicgeometry(MultiLineString, g.coordinates)
    elseif t == "MultiPolygon"
        return basicgeometry(MultiPolygon, g.coordinates)
    elseif t == "GeometryCollection"
        return basicgeometry(GeometryCollection, g.geometries)
    else
        throw(ArgumentError("Unknown geometry type"))
    end
end

function basicgeometry(::Type{Point}, g::JSON3.Array)
    return Point{2, Float64}(g)
end

function basicgeometry(::Type{LineString}, g::JSON3.Array)
    return LineString([Point{2, Float64}(p) for p in g], 1)
end

function basicgeometry(::Type{Polygon}, g::JSON3.Array)
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

function basicgeometry(::Type{MultiPoint}, g::JSON3.Array)
    return MultiPoint([basicgeometry(Point, x) for x in g])
end

function basicgeometry(::Type{MultiLineString}, g::JSON3.Array)
    return MultiLineString([basicgeometry(LineString, x) for x in g])
end

function basicgeometry(::Type{MultiPolygon}, g::JSON3.Array)
    return MultiPolygon([basicgeometry(Polygon, x) for x in g])
end

function basicgeometry(::Type{GeometryCollection}, g::JSON3.Array)
    return [basicgeometry(geom) for geom in g]
end

# https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_land.geojson
path_ne_10m_land = joinpath(@__DIR__, "..", "dev", "ne_10m_land.geojson")
bytes_ne_10m_land = read(path_ne_10m_land)

t = GeoJSONTables.read(bytes_ne_10m_land)
f = first(t)

GeoJSONTables.geometry(f)
basicgeometry(f)
[basicgeometry(f) for f in t]  # Vector{Any}

prop = GeoJSONTables.properties(f)
g = GeoJSONTables.geometry(f)

@btime GeoJSONTables.read($bytes_ne_10m_land)
# 53.805 ms (17 allocations: 800 bytes)
@btime [basicgeometry(f) for f in $t]
# 446.689 ms (2990547 allocations: 150.06 MiB)

# the file contains 9 MultiPolygons followed by 1 Polygon
# so StructArrays only works if we take the first 9 only

sa = StructArray([basicgeometry(f) for f in take(t, 9)])
# sa = StructArray([basicgeometry(f) for f in t])
