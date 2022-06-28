using GeoJSONTables
import GeoInterface as GI
import GeoFormatTypes
using Extents
using JSON3
using Tables
using Test

# copied from the GeoJSON.jl test suite
include("geojson_samples.jl")
featurecollections = [
    g,
    multipolygon,
    realmultipolygon,
    polyline,
    point,
    pointnull,
    poly,
    polyhole,
    collection,
    osm_buildings,
    empty_featurecollection,
]

@testset "Features" begin
    samples = (a, b, c, d, e, f, h)
    geometries = (
        nothing,
        [[-155.52, 19.61], [-156.22, 20.74], [-157.97, 21.46]],
        nothing,
        [[[3.75, 9.25], [-130.95, 1.52]], [[23.15, -34.25], [-1.35, -4.65], [3.45, 77.95]]],
        [53, -4],
        nothing,
        [[[3.75, 9.25], [-130.95, 1.52]], [[23.15, -34.25], [-1.35, -4.65], [3.45, 77.95]]],
    )
    properties = (
        [:Ã => "Ã"],
        [:type => "é"],
        [:type => "meow"],
        [:title => "Dict 1"],
        [
            :link => "http://example.org/features/1",
            :summary => "The first feature",
            :title => "Feature 1",
        ],
        [:foo => "bar"],
        [:title => "Dict 1", :bbox => [-180.0, -90.0, 180.0, 90.0]],
    )
    foreach(samples, properties) do s, p
        @test collect(GeoJSONTables.properties(GeoJSONTables.read(s))) == p
    end
    foreach(samples, geometries) do s, g
        @test GeoJSONTables.geometry(GeoJSONTables.read(s)) == g
    end
end

@testset "Geometries" begin
    geom = GeoJSONTables.read(multi)
    @test geom isa GeoJSONTables.MultiPolygon
    @test geom == [
        [[[180.0, 40.0], [180.0, 50.0], [170.0, 50.0], [170.0, 40.0], [180.0, 40.0]]],
        [[[-170.0, 40.0], [-170.0, 50.0], [-180.0, 50.0], [-180.0, 40.0], [-170.0, 40.0]]],
    ]

    geom = GeoJSONTables.read(geom_bbox)
    @test geom isa GeoJSONTables.LineString
    @test geom == [[-35.1, -6.6], [8.1, 3.8]]
    @test GI.crs(geom) == GeoFormatTypes.EPSG(4326)
    @test GeoJSONTables.bbox(geom) == [-35.1, -6.6, 8.1, 3.8]
    @test GI.extent(geom) == Extent(X = (-35.1, 8.1), Y = (-6.6, 3.8))
end

@testset "extent" begin
    @test GI.extent(GeoJSONTables.read(d)) ==
          Extent(X = (-180.0, 180.0), Y = (-90.0, 90.0))
    @test GI.extent(GeoJSONTables.read(e)) === nothing
    @test GI.extent(GeoJSONTables.read(g)) ==
          Extent(X = (100.0, 105.0), Y = (0.0, 1.0))
end

@testset "crs" begin
    @test GI.crs(GeoJSONTables.read(a)) == GeoFormatTypes.EPSG(4326)
    @test GI.crs(GeoJSONTables.read(g)) == GeoFormatTypes.EPSG(4326)
    @test GI.crs(GeoJSONTables.read(multi)) == GeoFormatTypes.EPSG(4326)
end

@testset "read not crash" begin
    for featurecollection in featurecollections
        GeoJSONTables.read(featurecollection)
    end
end

@testset "write" begin
    # Round trip read/write and compare prettified output to prettified original
    foreach((a, b, c, d, e, f, h)) do json
        f = GeoJSONTables.read(json)
        f1 = GeoJSONTables.read(GeoJSONTables.write(f))
        @test GeoJSONTables.geometry(f) == GeoJSONTables.geometry(f1)
        @test GeoJSONTables.properties(f) == GeoJSONTables.properties(f1)
        @test GI.extent(f) == GI.extent(f1)
    end

    foreach(featurecollections) do json
        fc = GeoJSONTables.read(json)
        f1c = GeoJSONTables.read(GeoJSONTables.write(fc))
        foreach(fc, f1c) do f, f1
            @test GeoJSONTables.geometry(f) == GeoJSONTables.geometry(f1)
            @test GeoJSONTables.properties(f) == GeoJSONTables.properties(f1)
            @test GI.extent(f) == GI.extent(f1)
        end
    end
end

@testset "FeatureCollection of one MultiPolygon" begin
    t = GeoJSONTables.read(g)
    @test Tables.istable(t)
    @test Tables.rows(t) === t
    @test Tables.columns(t) isa Tables.CopiedColumns
    @test t isa GeoJSONTables.FeatureCollection{
        <:GeoJSONTables.Feature,
        <:JSON3.Object,
        <:JSON3.Array,
    }
    @test Base.propertynames(t) == (:object, :features)  # override this?
    @test Tables.rowtable(t) isa Vector{<:NamedTuple}
    @test Tables.columntable(t) isa NamedTuple
    @inferred first(t)
    f1, _ = iterate(t)
    @test f1 isa GeoJSONTables.Feature{<:JSON3.Object}
    @test all(Base.propertynames(f1) .== [:cartodb_id, :addr1, :addr2, :park])
    @test all(propertynames(f1)) do pn
        getproperty(f1, pn) == getproperty(GI.getfeature(t, 1), pn)
    end
    @inferred t[1]
    @test f1 == t[1]
    geom = GeoJSONTables.geometry(f1)
    @test geom isa GeoJSONTables.MultiPolygon{<:JSON3.Object}
    @test geom isa GeoJSONTables.Geometry
    @test geom isa AbstractVector
    @test GeoJSONTables.object(geom) isa JSON3.Object
    @test GeoJSONTables.coordinates(geom) isa JSON3.Array
    @test GI.coordinates(geom) isa Vector
    @test GeoJSONTables.coordinates(geom)[1][1] == geom[1][1]
    @test length(geom[1][1]) == 4
    @test geom[1][1][1] == [-117.913883, 33.96657]
    @test geom[1][1][2] == [-117.907767, 33.967747]
    @test geom[1][1][3] == [-117.912919, 33.96445]
    @test geom[1][1][4] == [-117.913883, 33.96657]

    @testset "write to disk" begin
        fc = t
        GeoJSONTables.write("test.json", fc)
        fc1 = GeoJSONTables.read(read("test.json", String))
        @test GI.extent(fc) ==
              GI.extent(fc1) ==
              Extent(X = (100, 105), Y = (0, 1))
        f = GI.getfeature(fc, 1)
        f1 = GI.getfeature(fc1, 1)
        @test GI.geometry(f) == GI.geometry(f1)
        @test GI.properties(f) == GI.properties(f1)
        rm("test.json")
    end

    @testset "GeoInterface" begin
        @test GI.trait(t) == GI.FeatureCollectionTrait()
        geom = GeoJSONTables.geometry(f1)
        @test GI.trait(f1) === GI.FeatureTrait()
        @test GI.geomtrait(geom) === GI.MultiPolygonTrait()
        properties = GeoJSONTables.properties(f1)
        @test properties isa JSON3.Object
        @test properties["addr2"] === "Rowland Heights"
    end
end

@testset "FeatureCollection of one GeometryCollection" begin
    fc = GeoJSONTables.read(collection)
    gc = GeoJSONTables.geometry(GI.getfeature(fc, 1))
    @test GI.geomtrait(gc) isa GI.GeometryCollectionTrait

    @testset "Mixed geometry types are returned" begin
        @test GI.getgeom(gc, 1) isa GeoJSONTables.Polygon
        @test GI.getgeom(gc, 2) isa GeoJSONTables.Polygon
        @test GI.getgeom(gc, 3) isa GeoJSONTables.Point
    end
end

@testset "GeoInterface tests" begin
    geoms = [multi]
    @test all(s -> GI.testgeometry(s), GeoJSONTables.read.(geoms))
    features = [a, b, c, d, e, f, h]
    @test all(s -> GI.testfeature(s), GeoJSONTables.read.(features))
    featurecollections = [
        g,
        multipolygon,
        realmultipolygon,
        polyline,
        point,
        pointnull,
        poly,
        polyhole,
        collection,
        osm_buildings,
    ]
    @test all(
        s -> GI.testfeaturecollection(s),
        GeoJSONTables.read.(featurecollections),
    )
end

@testset "GeoFormatTypes" begin
    gft_str = GeoFormatTypes.GeoJSON(b)
    f = GeoJSONTables.read(gft_str)
    @test f isa GeoJSONTables.Feature

    dict = Dict{String,Any}("type" => "Point", "coordinates" => [-105.0, 39.5])
    gft_dict = GeoFormatTypes.GeoJSON(dict)
    p = GeoJSONTables.read(gft_dict)
    @test p isa GeoJSONTables.Point
end
