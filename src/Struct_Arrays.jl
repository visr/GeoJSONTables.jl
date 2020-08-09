getnamestypes(::Type{Feature{T, Names, Types}}) where {T, Names, Types} = (T, Names, Types) 

function StructArrays.staticschema(::Type{F}) where {F<:Feature} #explicitly give the "schema" of the object to StructArrays
    T, names, types = getnamestypes(F)
    NamedTuple{(:geometry, names...), Base.tuple_type_cons(T, types)}
end

function StructArrays.createinstance(::Type{F}, x, args...) where {F<:Feature} #generate an instance of Feature type 
     T , names, types = getnamestypes(F)
     Feature(x, NamedTuple{names, types}(args))
end

structarray(iter) = structarray(Tables.columntable(iter)::NamedTuple)
structarray(cols::NamedTuple) = structarray(first(cols), Base.tail(cols)) 

function structarray(geometry, properties::NamedTuple{names, types}) where {names, types}
    F = Feature{eltype(geometry), names, StructArrays.eltypes(types)}
    return StructArray{F}(; geometry=geometry, properties...)
end

