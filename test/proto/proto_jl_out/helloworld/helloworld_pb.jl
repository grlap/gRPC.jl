# Autogenerated using ProtoBuf.jl v1.0.10 on 2023-03-04T19:01:01.320
# original file: f:\GitHub\Personal\gRPC.jl\test\proto\helloworld.proto (proto3 syntax)

import ProtoBuf as PB
using ProtoBuf: OneOf
using ProtoBuf.EnumX: @enumx

export HelloReply, HelloRequest, Greeter

struct HelloReply
    message::String
end
PB.default_values(::Type{HelloReply}) = (;message = "")
PB.field_numbers(::Type{HelloReply}) = (;message = 1)

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:HelloReply})
    message = ""
    while !PB.message_done(d)
        field_number, wire_type = PB.decode_tag(d)
        if field_number == 1
            message = PB.decode(d, String)
        else
            PB.skip(d, wire_type)
        end
    end
    return HelloReply(message)
end

function PB.encode(e::PB.AbstractProtoEncoder, x::HelloReply)
    initpos = position(e.io)
    !isempty(x.message) && PB.encode(e, 1, x.message)
    return position(e.io) - initpos
end
function PB._encoded_size(x::HelloReply)
    encoded_size = 0
    !isempty(x.message) && (encoded_size += PB._encoded_size(x.message, 1))
    return encoded_size
end

struct HelloRequest
    name::String
end
PB.default_values(::Type{HelloRequest}) = (;name = "")
PB.field_numbers(::Type{HelloRequest}) = (;name = 1)

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:HelloRequest})
    name = ""
    while !PB.message_done(d)
        field_number, wire_type = PB.decode_tag(d)
        if field_number == 1
            name = PB.decode(d, String)
        else
            PB.skip(d, wire_type)
        end
    end
    return HelloRequest(name)
end

function PB.encode(e::PB.AbstractProtoEncoder, x::HelloRequest)
    initpos = position(e.io)
    !isempty(x.name) && PB.encode(e, 1, x.name)
    return position(e.io) - initpos
end
function PB._encoded_size(x::HelloRequest)
    encoded_size = 0
    !isempty(x.name) && (encoded_size += PB._encoded_size(x.name, 1))
    return encoded_size
end

# SERVICE: Greeter
using gRPC
const _Greeter_methods =
[
    ("SayHello", 1, HelloRequest, HelloReply),
] # const _Greeter_methods
const _Greeter_desc = gRPC.ServiceDescriptor(string(nameof(@__MODULE__)) * ".Greeter", 1, _Greeter_methods)
Greeter(impl::Module) = gRPC.ProtoService(_Greeter_desc, impl)

mutable struct GreeterBlockingStub <: gRPC.AbstractProtoServiceStub{true}
    impl::gRPC.ProtoServiceBlockingStub
    GreeterBlockingStub(channel::gRPC.ProtoRpcChannel) = new(gRPC.ProtoServiceBlockingStub(_Greeter_desc, channel))
end # mutable struct GreeterBlockingStub

SayHello(stub::GreeterBlockingStub, controller::gRPC.ProtoRpcController, input_instance) =
    call_method(stub.impl, "SayHello", HelloRequest, HelloReply, controller, input_instance)

export SayHello
# End SERVICE Greeter