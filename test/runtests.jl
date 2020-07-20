using GeoJSONTables
using JSON3
using Tables
using Test
using GeometryBasics
using GeometryBasics.StructArrays

# copied from the GeoJSON.jl test suite
include("geojson_samples.jl")
featurecollections = [g, multipolygon, realmultipolygon, polyline, point, pointnull,
    poly, polyhole, collection, osm_buildings, test1]

json = JSON3.read(a)
jsonfeatures = get(json, :features, nothing)

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
        @test_throws ArgumentError GeoJSONTables.read(test)
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
        @test Tables.columns(t) isa Tables.ColumnTable
        @test t isa StructArray
        @test Base.propertynames(t) == (:geometry, :cartodb_id, :addr1, :addr2, :park)
        @test Tables.rowtable(t) isa Vector{<:NamedTuple}
        @test Tables.columntable(t) isa NamedTuple

        f1, _ = iterate(t)
        @test f1 isa GeoJSONTables.Feature
        @test Base.propertynames(f1) == (:geometry, :cartodb_id, :addr1, :addr2, :park) #we'll need to add it for StructArrays anyway
        @test f1 == t[1]
        multipolygon = GeoJSONTables.geometry(f1)
        @test multipolygon isa MultiPolygon
        linestring = multipolygon[1].exterior
        @test length(linestring) == 3
        @test linestring[1] == Line(Point(-117.913883, 33.96657), Point(-117.907767, 33.967747))
        @test linestring[2] == Line(Point(-117.907767, 33.967747), Point(-117.912919, 33.96445))
        @test linestring[3] == Line(Point(-117.912919, 33.96445), Point(-117.913883, 33.96657))
        for s in Base.propertynames(f1)
            if s == :geometry
                @test Base.getproperty(f1, s) == GeoJSONTables.geometry(f1)
            else
                @test Base.getproperty(f1, s) == 46 ||
                      Base.getproperty(f1, s) == "18150 E. Pathfinder Rd." ||
                      Base.getproperty(f1, s) == "Rowland Heights" ||
                      Base.getproperty(f1, s) == "Pathfinder Park"
            end
        end
        @test GeoJSONTables.properties(f1) == (cartodb_id = 46, addr1 = "18150 E. Pathfinder Rd.", addr2 = "Rowland Heights", park = "Pathfinder Park")
        @test sprint(GeoJSONTables.show, t) == "FeatureCollection with 1 Features\n"

    end
    
    s = [GeoJSONTables.Feature(Point(1, 2), city="Mumbai", rainfall=1000),
             GeoJSONTables.Feature(Point(3.78415165, 2131513), city="Dehi", rainfall=200.56444),
             GeoJSONTables.Feature(MultiPoint([Point(5.6565465, 8.913513), Point(1.89546548, 2.6923515)]), city = "Goa", rainfall = 900)]
    iter = (i for  i in s)
    sa = GeoJSONTables.structarray(iter)
    
    @testset "Test Miscellaneous helper methods" begin
        f = GeoJSONTables.Feature(Point(1, 2), city = "Mumbai", rainfall = 1000)
        @test sprint(GeoJSONTables.show, f) == 
        "Feature with geometry type Point and properties (:geometry, :city, :rainfall)\n"

        @test s isa Vector
        @test iter isa Base.Generator
        @test sa isa StructArray
        @test length(s) == 3
        @test GeoJSONTables.getnamestypes(typeof(f)) == (Point{2,Int64}, (:city, :rainfall), Tuple{String,Int64})
        @test StructArrays.staticschema(typeof(f)) == NamedTuple{(:geometry, :city, :rainfall),Tuple{Point{2,Int64},String,Int64}}
    end

    @testset "Reversbility of features remain after creating StructArray" begin
        row = sa[1]
        @test GeoJSONTables.properties(row) == (city="Mumbai", rainfall=1000)
        @test GeoJSONTables.geometry(row) == Point(1, 2)
    end
    
    @testset "Other Feature Collections" begin
        for i in featurecollections
            
            t = GeoJSONTables.read(i)
            @test Tables.istable(t)
            @test Tables.rows(t) === t
            @test Tables.columns(t) isa Tables.ColumnTable
            @test t isa StructArray
            @test Base.propertynames(t) == (:geometry, keys(GeoJSONTables.properties(t[1]))...)
            @test Tables.rowtable(t) isa Vector{<:NamedTuple}
            @test Tables.columntable(t) isa NamedTuple

            f1, _ = iterate(t)
            geom = f1.geometry
            prop = GeoJSONTables.properties(f1)
            a = geom, prop...
            @test f1 isa GeoJSONTables.Feature
            @test Base.propertynames(t) == (:geometry, keys(GeoJSONTables.properties(t[1]))...)
            @test f1 == t[1]
            @test GeoJSONTables.getnamestypes(typeof(f1)) == (typeof(geom), keys(prop), typeof(values(prop)))
            @test StructArrays.staticschema(typeof(f1)) == NamedTuple{Base.propertynames(f1),typeof(a)}
            @test_throws ArgumentError GeoJSONTables.read(unknown_geom)
            @test GeoJSONTables.miss(f1) == f1 
            @test "$(GeoJSONTables.miss([:a, :b]))" == "(a = missing, b = missing)"
        end
    end

    @testset "Reading features" begin
        for geom in missing_prop
            @test "$(GeoJSONTables.geo2feat(geom))" == 
            "Feature with geometry type $(nameof(typeof(geom))) and properties (:geometry, :missing)\n"

            @test "$(GeoJSONTables.geo2feat(geom, prop))" == 
            "Feature with geometry type $(nameof(typeof(geom))) and properties (:geometry, :city, :rainfall)\n"

            @test "$(GeoJSONTables.geo2feat(geom, city = "Mumbai", rainfall = 1010))" == 
            "Feature with geometry type $(nameof(typeof(geom))) and properties (:geometry, :city, :rainfall)\n"
        end
    end
end

