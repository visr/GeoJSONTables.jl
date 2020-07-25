# GeoJSONTables
[![Build Status](https://travis-ci.com/visr/GeoJSONTables.jl.svg?branch=master)](https://travis-ci.com/visr/GeoJSONTables.jl)
[![Codecov](https://codecov.io/gh/visr/GeoJSONTables.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/visr/GeoJSONTables.jl)

Read [GeoJSON](https://geojson.org/) [FeatureCollections](https://tools.ietf.org/html/rfc7946#section-3.3) using [JSON3.jl](https://github.com/quinnj/JSON3.jl), and provide the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface via [StructArrays.jl](https://github.com/JuliaArrays/StructArrays.jl).

This package is unregistered and in development, so expect changes. 
For now it supports reading, of the following 
* GeoJSON FeatureCollections
* [GeometryBasics](https://github.com/JuliaGeometry/GeometryBasics.jl) geometries as Features 
  
This package is heavily inspired by [JSONTables.jl](https://github.com/JuliaData/JSONTables.jl), which
does the same thing for the general JSON format. GeoJSONTables puts the geometry in a `geometry` column, and adds all
properties in the columns individually. The geometry and non-scalar properties are kept as GeometryBasics geometries and NamedTuple respectively.
A StructArray of `Features` represents a `FeatureCollection`. The StructArrays approach is inspired by GeometryBasics.
For a faster/lower level interface, the geojson can be can also be parsed as a JSON3 dictionary.

Going forward, it would be nice to try developing a GeoTables.jl, similarly to Tables.jl, but with special support for a geometry column, that supports a diverse set of geometries, such as those of [LibGEOS](https://github.com/JuliaGeo/LibGEOS.jl), [Shapefile](https://github.com/JuliaGeo/Shapefile.jl), 
[ArchGDAL.jl](https://github.com/yeesian/ArchGDAL.jl/), [GeometryBasics](https://github.com/SimonDanisch/GeometryBasics.jl) and of course this package.

It would also be good to explore integrating this code into [GeoJSON.jl](https://github.com/JuliaGeo/GeoJSON.jl) and
archiving this package. See [GeoJSON.jl#23](https://github.com/JuliaGeo/GeoJSON.jl/pull/23) for discussion.

## Usage

```julia
julia> using GeoJSONTables, DataFrames, GeometryBasics

julia> jsonbytes = read("path/to/a.geojson");

julia> fc = GeoJSONTables.read(jsonbytes)
FeatureCollection with 171 Features

julia> first(fc)
Feature with geometry type Polygon and properties (:geometry, :timestamp, :version, :changeset, :user, :uid, :area, :highway, :type, :id)

# use the Tables interface to convert the format, extract data, or iterate over the rows
julia> df = DataFrame(fc)

# GeometryBasics geometries can be passed along with metadata, into a Feature
julia> f = GeoJSONTables.Feature(Point(1.0, 2.0), city = "Mumbai", rainfall = 1010)
Feature with geometry type Point and properties (:geometry, :city, :rainfall)

# metdata can be also passed as a NamedTuple 
julia> prop = (city = "Delhi", rainfall = 200)
(city = "Delhi", rainfall = 200)

julia> f = GeoJSONTables.Feature(Point(100.0, 200.0), prop)
Feature with geometry type Point and properties (:geometry, :city, :rainfall)

# for a lower level JSON3 interface(read the jsonbytes as a JSON3 object)
using GeoJSONTables.JSON3

julia> JSON3.read(jsonbytes)
JSON3.Object{Array{UInt8,1},Array{UInt64,1}} with 4 entries:
    :type     => "FeatureCollection"
    :name     => "a"
    :crs      => {…
    :features => JSON3.Object[{…

```
