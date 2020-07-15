module GeoJSONTables

import JSON3, Tables
using GeometryBasics
using GeometryBasics.StructArrays

struct Feature{T, Names, Types}
    geometry::T
    properties::NamedTuple{Names, Types}
end

Feature(x; kwargs...) = Feature(x, values(kwargs)) #size of properties is not fixed

"""
Read raw jsonbytes into StructArray
"""
function read(source)
    features = Feature[]
    a = Symbol[]
    fc = JSON3.read(source)
    jsonfeatures = get(fc, :features, nothing)
    for f in jsonfeatures 
        prop = f.properties
        if !=(get(f, :properties, nothing), nothing)
            a = propertynames(prop)   #store the property names well before, for StructArrays
            break
        end
    end
    if get(fc, :type, nothing) == "FeatureCollection" && jsonfeatures isa JSON3.Array
        for f in jsonfeatures 
            geom = f.geometry
            prop = f.properties
            
            if !=(geom, nothing) && prop === nothing                      #only properties missing
                push!(features, Feature(geometry(geom), miss(a)))
            elseif geom === nothing && !=(prop, nothing)                  #only geometry missing
                push!(features, Feature(missing, (; zip(keys(prop), values(prop))...)))
            elseif !=(geom, nothing) && !=(prop, nothing)                 #none missing
                push!(features, Feature(geometry(geom), (; zip(keys(prop), values(prop))...)))
            elseif geom === nothing && prop === nothing                   #both missing
                push!(features, Feature(missing, miss(a)))
            end
        end
        iter = (i for i in features)
        structarray(iter)
    else
        throw(ArgumentError("input source is not a GeoJSON FeatureCollection"))
    end
end

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
function Base.getproperty(f::Feature, s::Symbol)
    if s == :geometry
        val = getfield(f, 1)
        miss(val)
    else
        val = getproperty(getfield(f, 2), s)
        miss(val)
    end
end

function miss(x)
    if x isa Array{Symbol, 1} && !isempty(x)                #incase a few properties are present
        val = fill(missing, length(x))
        return NamedTuple{Tuple(x)}(val)
    elseif x isa Array{Symbol, 1} && isempty(x)             #incase all the properties are missing 
        return NamedTuple{Tuple([:properties])}([missing])
    elseif x === missing
        return missing
    else
        return x
    end
end

function Base.show(io::IO, f::Feature)
    geomtype = nameof(typeof(geometry(f)))
    println(io, "Feature with geometry type $geomtype and properties $(propertynames(f))")
end
Base.show(io::IO, ::MIME"text/plain", f::Feature) = show(io, f)

include("Struct_Arrays.jl")
include("geometry_basics.jl")

end # module
