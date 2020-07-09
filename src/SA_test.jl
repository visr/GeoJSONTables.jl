using GeometryBasics
using GeometryBasics.StructArrays

p1 = Point(2, 1)
p2 = Point(3, 2)

Feature(x; kwargs...) = Feature(x, values(kwargs))

Base.getproperty(x::Feature, s::Symbol) = s == :geometry ? getfield(x, 1) : getproperty(getfield(x, 2), s) # looking for `s` in `properties`

getnamestypes(::Type{Feature{T, Names, Types}}) where {T, Names, Types} = (T, Names, Types)

function StructArrays.staticschema(::Type{F}) where {F<:Feature}
#=
    the problem currently is the type of F we're getting here (uncommenting the println(F))
    For homogeneous data "GeoJSONTables.Feature{GeometryBasics.Point{2,Int64},(:a, :b),Tuple{String,Int64}}" comes out
    While for heterogeneous data Feature{T,(:a, :b),Tuple{String,Int64}} where T or Feature{T,(:a, :b),Types} where Types where T
    So basically we're getting T/Types instead of concrete types depending on whateve is heterogeneous
    with a no method matching getnametypes() error
=#
    # println(F)
    T, names, types = getnamestypes(F)
    NamedTuple{(:geometry, names...), Base.tuple_type_cons(T, types)}
end

function StructArrays.createinstance(::Type{F}, x, args...) where {F<:Feature}
    T , names, types = getnamestypes(F)
    Feature(x, NamedTuple{names, types}(args))
end

s = [Feature(Point(1, 2), a="1", b=2),  Feature(Point(3, 2), a="2", b=4)] #homogeneous data

#other examples
# s = [Feature(Point(1, 2), a="1", b=2),  Feature(Point(3.0, 2), a="2", b=4)] # point heterogeneous
# s = [Feature(Point(1, 2), a="1", b=2),  Feature(Point(3, 2), a="2", b=4.0)] # meta heterogeneous
# s = [Feature(Point(1, 2), a="1", b=2),  Feature(Point(3, 2), a="2", b=4.0) , Feature(MultiPoint([p1, p2]), a = "5", b = 6.0)]

sa = StructArray(s)
# println(sa)
