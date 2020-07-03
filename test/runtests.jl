using GeoJSONTables
using JSON3
using Tables
using Test
using GeometryBasics

# copied from the GeoJSON.jl test suite
include("geojson_samples.jl")
featurecollections = [g, multipolygon, realmultipolygon, polyline, point, pointnull,
    poly, polyhole, collection, osm_buildings]

@testset "GeoJSONTables.jl" begin
    # only FeatureCollection supported for now
    @testset "Not FeatureCollections" begin
        @test_throws ArgumentError GeoJSONTables.read(a)
        @test_throws ArgumentError GeoJSONTables.read(b)
        @test_throws ArgumentError GeoJSONTables.read(c)
        @test_throws ArgumentError GeoJSONTables.read(d)
        @test_throws ArgumentError GeoJSONTables.read(e)
        @test_throws ArgumentError GeoJSONTables.read(f)
        @test_throws ArgumentError GeoJSONTables.read(h)
    end

    @testset "Read not crash" begin
        for featurecollection in featurecollections
            GeoJSONTables.read(featurecollection)
        end
    end

    @testset "FeatureCollection of one MultiPolygon" begin
        t = GeoJSONTables.read(g)
        @test Tables.istable(t)
        @test Tables.rows(t) === t
        @test Tables.columns(t) isa Tables.CopiedColumns
        @test t isa GeoJSONTables.FeatureCollection
        @test Base.propertynames(t) == (:features,)  # override this?
        @test Tables.rowtable(t) isa Vector{<:NamedTuple}
        @test Tables.columntable(t) isa NamedTuple

        f1, _ = iterate(t)
        @test f1 isa GeoJSONTables.Feature
        @test isempty(Base.propertynames(f1)) # .== [:cartodb_id, :addr1, :addr2, :park])
        @test f1 == t[1]
        multipolygon = GeoJSONTables.geometry(f1)
        @test multipolygon isa MultiPolygon
        linestring = multipolygon[1].exterior
        @test length(linestring) == 3
        @test linestring[1] == Line(Point(-117.913883, 33.96657), Point(-117.907767, 33.967747))
        @test linestring[2] == Line(Point(-117.907767, 33.967747), Point(-117.912919, 33.96445))
        @test linestring[3] == Line(Point(-117.912919, 33.96445), Point(-117.913883, 33.96657))
    end
end
