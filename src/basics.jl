function basicgeometry(fc::GeoJSONTables.FeatureCollection)
    geom = [basicgeometry(feat) for feat in fc]
    structarray(geom)
end
 
function basicgeometry(f::GeoJSONTables.Feature)
    geom = geometry(f)
    prop = properties(f)
    
    t = geom.type
    k = Tuple(keys(prop))
    v = Tuple(values(prop))
    tup = NamedTuple{k}(v)
    
    if t == "Point"
        # geom.coordinates = pt(a)
        return basicgeometry(Point, geom.coordinates, tup)
    elseif t == "LineString"
        return basicgeometry(LineString, geom.coordinates, tup)
    elseif t == "Polygon"
        return basicgeometry(Polygon, geom.coordinates, tup)
    elseif t == "MultiPoint"
        return basicgeometry(MultiPoint, geom.coordinates, tup)
    elseif t == "MultiLineString"
        return basicgeometry(MultiLineString, geom.coordinates, tup)
    elseif t == "MultiPolygon"
        return basicgeometry(MultiPolygon, geom.coordinates, tup)
    elseif t == "FeatureCollection"
        return basicgeometry(FeatureCollection, geom.geometries, tup)
    else
        throw(ArgumentError("Unknown geometry type"))
    end
end

function basicgeometry(::Type{Point}, g, tup::NamedTuple)
    pt = Point{2, Float64}(g)
    return GeometryBasics.Meta(pt, tup)
end

function basicgeometry(::Type{Point}, g)
    return Point{2, Float64}(g)
end

function basicgeometry(::Type{LineString} , g, tup::NamedTuple)
    coord = Point{2, Float64}[]
    for i in 1:length(g)
        push!(coord,collect(pts for pts in g[1]))
    end
    
    return LineStringMeta(LineString([Point{2, Float64}(p) for p in coord], 1), tup)
end

function basicgeometry(::Type{LineString} , g)
    return LineString([Point{2, Float64}(p) for p in g], 1)
end

function basicgeometry(::Type{Polygon}, g, tup::NamedTuple)
    coord = Array{Point{2, Float64}}[]
    for i in 1:length(g)
        push!(coord,collect(pts for pts in g[1]))
    end
    # TODO introduce LinearRing type in GeometryBasics?
    nring = length(coord)
    exterior = LineString([Point{2, Float64}(p) for p in coord[1]], 1)
    if nring == 1  # only exterior
        poly =  Polygon(exterior)
        return PolygonMeta(poly, tup)
    else  # exterior and interior(s)
        interiors = Vector{typeof(exterior)}(undef, nring)
        for i in 2:nring
            interiors[i-1] = LineString([Point{2, Float64}(p) for p in coord[i]], 1)
        end
        poly =  Polygon(exterior, interiors)
        return PolygonMeta(poly, tup)
    end
end
"""
will receive stuff from MultiPolygon
"""
function basicgeometry(::Type{Polygon}, g)
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


function basicgeometry(::Type{MultiPoint}, g, tup::NamedTuple)
    coord = Point{2, Float64}[]
    for i in 1:length(g)
        push!(coord,collect(pts for pts in g[1]))
    end
    
    return MultiPointMeta([basicgeometry(Point, x) for x in coord], tup)
end

function basicgeometry(::Type{MultiLineString}, g, tup::NamedTuple)
    coord = Array{Point{2, Float64}}[]
    for i in 1:length(g)
        push!(coord,collect(pts for pts in g[1]))
    end
    
    return MultiLineStringMeta([basicgeometry(LineString, x) for x in coord], tup)
end

function basicgeometry(::Type{MultiPolygon}, g, tup::NamedTuple)
    coord = Array{Array{Point{2, Float64}}}[]
    for i in 1:length(g)
        push!(coord,collect(pts for pts in g[1]))
    end
    poly = [basicgeometry(Polygon, x) for x in coord]
    return MultiPolygonMeta(poly; tup...)
end

function basicgeometry(::Type{FeatureCollection}, g, tup::NamedTuple)
    #todo workout a way to represent metadata in this case
    return [basicgeometry(geom) for geom in g] 
end

function structarray(geom)
    meta = collect(GeometryBasics.meta(s) for s in geom)
    meta_cols = Tables.columntable(meta)
    return StructArray(Geometry = collect(GeometryBasics.metafree(i) for  i in geom); meta_cols...)
end


# @btime GeoJSONTables.read($bytes_ne_10m_land)
# # 53.805 ms (17 allocations: 800 bytes)
# @btime [basicgeometry(f) for f in $t]
# # 446.689 ms (2990547 allocations: 150.06 MiB)

# # the file contains 9 MultiPolygons followed by 1 Polygon
# # so StructArrays only works if we take the first 9 only

# sa = StructArray([basicgeometry(f) for f in take(t, 9)])
# sa = StructArray([basicgeometry(f) for f in t])
