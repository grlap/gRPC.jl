# Autogenerated using ProtoBuf.jl v1.0.10 on 2023-03-05T12:48:47.934
# original file: F:\GitHub\Personal\gRPC.jl\test\proto\route_guide.proto (proto3 syntax)

import ProtoBuf as PB
using ProtoBuf: OneOf
using ProtoBuf.EnumX: @enumx

export Point, RouteSummary, Empty, RouteNote, Rectangle, Feature, RouteGuide

struct Point
    latitude::Int32
    longitude::Int32
end
PB.default_values(::Type{Point}) = (;latitude = zero(Int32), longitude = zero(Int32))
PB.field_numbers(::Type{Point}) = (;latitude = 1, longitude = 2)

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:Point})
    latitude = zero(Int32)
    longitude = zero(Int32)
    while !PB.message_done(d)
        field_number, wire_type = PB.decode_tag(d)
        if field_number == 1
            latitude = PB.decode(d, Int32)
        elseif field_number == 2
            longitude = PB.decode(d, Int32)
        else
            PB.skip(d, wire_type)
        end
    end
    return Point(latitude, longitude)
end

function PB.encode(e::PB.AbstractProtoEncoder, x::Point)
    initpos = position(e.io)
    x.latitude != zero(Int32) && PB.encode(e, 1, x.latitude)
    x.longitude != zero(Int32) && PB.encode(e, 2, x.longitude)
    return position(e.io) - initpos
end
function PB._encoded_size(x::Point)
    encoded_size = 0
    x.latitude != zero(Int32) && (encoded_size += PB._encoded_size(x.latitude, 1))
    x.longitude != zero(Int32) && (encoded_size += PB._encoded_size(x.longitude, 2))
    return encoded_size
end

struct RouteSummary
    point_count::Int32
    feature_count::Int32
    distance::Int32
    elapsed_time::Int32
end
PB.default_values(::Type{RouteSummary}) = (;point_count = zero(Int32), feature_count = zero(Int32), distance = zero(Int32), elapsed_time = zero(Int32))
PB.field_numbers(::Type{RouteSummary}) = (;point_count = 1, feature_count = 2, distance = 3, elapsed_time = 4)

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:RouteSummary})
    point_count = zero(Int32)
    feature_count = zero(Int32)
    distance = zero(Int32)
    elapsed_time = zero(Int32)
    while !PB.message_done(d)
        field_number, wire_type = PB.decode_tag(d)
        if field_number == 1
            point_count = PB.decode(d, Int32)
        elseif field_number == 2
            feature_count = PB.decode(d, Int32)
        elseif field_number == 3
            distance = PB.decode(d, Int32)
        elseif field_number == 4
            elapsed_time = PB.decode(d, Int32)
        else
            PB.skip(d, wire_type)
        end
    end
    return RouteSummary(point_count, feature_count, distance, elapsed_time)
end

function PB.encode(e::PB.AbstractProtoEncoder, x::RouteSummary)
    initpos = position(e.io)
    x.point_count != zero(Int32) && PB.encode(e, 1, x.point_count)
    x.feature_count != zero(Int32) && PB.encode(e, 2, x.feature_count)
    x.distance != zero(Int32) && PB.encode(e, 3, x.distance)
    x.elapsed_time != zero(Int32) && PB.encode(e, 4, x.elapsed_time)
    return position(e.io) - initpos
end
function PB._encoded_size(x::RouteSummary)
    encoded_size = 0
    x.point_count != zero(Int32) && (encoded_size += PB._encoded_size(x.point_count, 1))
    x.feature_count != zero(Int32) && (encoded_size += PB._encoded_size(x.feature_count, 2))
    x.distance != zero(Int32) && (encoded_size += PB._encoded_size(x.distance, 3))
    x.elapsed_time != zero(Int32) && (encoded_size += PB._encoded_size(x.elapsed_time, 4))
    return encoded_size
end

struct Empty  end

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:Empty})
    while !PB.message_done(d)
        field_number, wire_type = PB.decode_tag(d)
        PB.skip(d, wire_type)
    end
    return Empty()
end

function PB.encode(e::PB.AbstractProtoEncoder, x::Empty)
    initpos = position(e.io)
    return position(e.io) - initpos
end
function PB._encoded_size(x::Empty)
    encoded_size = 0
    return encoded_size
end

struct RouteNote
    location::Union{Nothing,Point}
    message::String
end
PB.default_values(::Type{RouteNote}) = (;location = nothing, message = "")
PB.field_numbers(::Type{RouteNote}) = (;location = 1, message = 2)

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:RouteNote})
    location = Ref{Union{Nothing,Point}}(nothing)
    message = ""
    while !PB.message_done(d)
        field_number, wire_type = PB.decode_tag(d)
        if field_number == 1
            PB.decode!(d, location)
        elseif field_number == 2
            message = PB.decode(d, String)
        else
            PB.skip(d, wire_type)
        end
    end
    return RouteNote(location[], message)
end

function PB.encode(e::PB.AbstractProtoEncoder, x::RouteNote)
    initpos = position(e.io)
    !isnothing(x.location) && PB.encode(e, 1, x.location)
    !isempty(x.message) && PB.encode(e, 2, x.message)
    return position(e.io) - initpos
end
function PB._encoded_size(x::RouteNote)
    encoded_size = 0
    !isnothing(x.location) && (encoded_size += PB._encoded_size(x.location, 1))
    !isempty(x.message) && (encoded_size += PB._encoded_size(x.message, 2))
    return encoded_size
end

struct Rectangle
    lo::Union{Nothing,Point}
    hi::Union{Nothing,Point}
end
PB.default_values(::Type{Rectangle}) = (;lo = nothing, hi = nothing)
PB.field_numbers(::Type{Rectangle}) = (;lo = 1, hi = 2)

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:Rectangle})
    lo = Ref{Union{Nothing,Point}}(nothing)
    hi = Ref{Union{Nothing,Point}}(nothing)
    while !PB.message_done(d)
        field_number, wire_type = PB.decode_tag(d)
        if field_number == 1
            PB.decode!(d, lo)
        elseif field_number == 2
            PB.decode!(d, hi)
        else
            PB.skip(d, wire_type)
        end
    end
    return Rectangle(lo[], hi[])
end

function PB.encode(e::PB.AbstractProtoEncoder, x::Rectangle)
    initpos = position(e.io)
    !isnothing(x.lo) && PB.encode(e, 1, x.lo)
    !isnothing(x.hi) && PB.encode(e, 2, x.hi)
    return position(e.io) - initpos
end
function PB._encoded_size(x::Rectangle)
    encoded_size = 0
    !isnothing(x.lo) && (encoded_size += PB._encoded_size(x.lo, 1))
    !isnothing(x.hi) && (encoded_size += PB._encoded_size(x.hi, 2))
    return encoded_size
end

struct Feature
    name::String
    location::Union{Nothing,Point}
end
PB.default_values(::Type{Feature}) = (;name = "", location = nothing)
PB.field_numbers(::Type{Feature}) = (;name = 1, location = 2)

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:Feature})
    name = ""
    location = Ref{Union{Nothing,Point}}(nothing)
    while !PB.message_done(d)
        field_number, wire_type = PB.decode_tag(d)
        if field_number == 1
            name = PB.decode(d, String)
        elseif field_number == 2
            PB.decode!(d, location)
        else
            PB.skip(d, wire_type)
        end
    end
    return Feature(name, location[])
end

function PB.encode(e::PB.AbstractProtoEncoder, x::Feature)
    initpos = position(e.io)
    !isempty(x.name) && PB.encode(e, 1, x.name)
    !isnothing(x.location) && PB.encode(e, 2, x.location)
    return position(e.io) - initpos
end
function PB._encoded_size(x::Feature)
    encoded_size = 0
    !isempty(x.name) && (encoded_size += PB._encoded_size(x.name, 1))
    !isnothing(x.location) && (encoded_size += PB._encoded_size(x.location, 2))
    return encoded_size
end

# SERVICE: RouteGuide
const _RouteGuide_methods = Dict(
    "GetFeature" => (Symbol("GetFeature"), 1, Point, Feature),
    "ListFeatures" => (Symbol("ListFeatures"), 2, Rectangle, AbstractChannel{Feature}),
    "RecordRoute" => (Symbol("RecordRoute"), 3, AbstractChannel{Point}, RouteSummary),
    "RouteEcho" => (Symbol("RouteEcho"), 4, RouteNote, RouteNote),
    "RouteChat" => (Symbol("RouteChat"), 5, AbstractChannel{RouteNote}, AbstractChannel{RouteNote}),
    "TerminateServer" => (Symbol("TerminateServer"), 6, Empty, Empty),
) # const _RouteGuide_methods
const _RouteGuide_const = string(nameof(@__MODULE__)) * ".RouteGuide"
const _RouteGuide_desc = (_RouteGuide_const, 1, _RouteGuide_methods)
RouteGuide(impl::Module) = (_RouteGuide_desc, impl)

GetFeature(stub_impl, controller, input_instance) =
    call_method(stub_impl, "GetFeature", Point, Feature, controller, input_instance)

ListFeatures(stub_impl, controller, input_instance) =
    call_method(stub_impl, "ListFeatures", Rectangle, AbstractChannel{Feature}, controller, input_instance)

RecordRoute(stub_impl, controller, input_instance) =
    call_method(stub_impl, "RecordRoute", AbstractChannel{Point}, RouteSummary, controller, input_instance)

RouteEcho(stub_impl, controller, input_instance) =
    call_method(stub_impl, "RouteEcho", RouteNote, RouteNote, controller, input_instance)

RouteChat(stub_impl, controller, input_instance) =
    call_method(stub_impl, "RouteChat", AbstractChannel{RouteNote}, AbstractChannel{RouteNote}, controller, input_instance)

TerminateServer(stub_impl, controller, input_instance) =
    call_method(stub_impl, "TerminateServer", Empty, Empty, controller, input_instance)

export GetFeature
export ListFeatures
export RecordRoute
export RouteEcho
export RouteChat
export TerminateServer
# End SERVICE RouteGuide
