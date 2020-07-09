using GeometryBasics
using GeometryBasics.StructArrays

p1 = Point(2, 1)
p2 = Point(3, 2)

Feature(x; kwargs...) = Feature(x, values(kwargs))

getnamestypes(::Type{Feature{T, Names, Types}}) where {T, Names, Types} = (T, Names, Types)

function StructArrays.staticschema(::Type{F}) where {F<:Feature}
    T, names, types = getnamestypes(F)
    NamedTuple{(:geometry, names...), Base.tuple_type_cons(T, types)}
end

Base.propertynames(f::Feature) = (:geometry, keys(properties(f))...)
Base.getproperty(f::Feature, s::Symbol) = s == :geometry ? getfield(f, 1) : getproperty(getfield(f, 2), s) # looking for `s` in `properties`

s = [Feature(Point(1, 2), a="1", b=2), Feature(Point(3.0, 2), a="2", b=4.0) , Feature(MultiPoint([p1, p2]), a = "5", b = 6.0)]
iter = (i for  i in s)

maketable(iter) = maketable(Tables.columntable(iter)::NamedTuple)

# assuming `geometry` is first in `propertynames(f::Feature)`
maketable(cols::NamedTuple) = maketable(first(cols), Base.tail(cols)) # you could also compute the types here with `Base.tuple_type_tail` and `Base.tuple_type_head`

function maketable(geometry, properties::NamedTuple{names, types}) where {names, types}
    F = Feature{eltype(geometry), names, StructArrays.eltypes(types)}
    return StructArray{F}(; geometry=geometry, properties...)
end
sa = maketable(iter)
