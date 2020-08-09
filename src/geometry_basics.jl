"""
Take the JSON3 representation of a GeoJSON geometry
and convert it to the corresponding GeometryBasics geometry.
"""
function geometry end

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
        interiors = Vector{typeof(exterior)}(undef, nring-1)
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
