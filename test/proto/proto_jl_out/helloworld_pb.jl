# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

mutable struct HelloRequest <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function HelloRequest(; kwargs...)
        obj = new(meta(HelloRequest), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        return obj
    end
end # mutable struct HelloRequest
const __meta_HelloRequest = Ref{ProtoMeta}()
function meta(::Type{HelloRequest})
    ProtoBuf.metalock() do
        if !isassigned(__meta_HelloRequest)
            __meta_HelloRequest[] = target = ProtoMeta(HelloRequest)
            allflds = Pair{Symbol,Union{Type,String}}[:name => AbstractString]
            meta(
                target,
                HelloRequest,
                allflds,
                ProtoBuf.DEF_REQ,
                ProtoBuf.DEF_FNUM,
                ProtoBuf.DEF_VAL,
                ProtoBuf.DEF_PACK,
                ProtoBuf.DEF_WTYPES,
                ProtoBuf.DEF_ONEOFS,
                ProtoBuf.DEF_ONEOF_NAMES,
            )
        end
        __meta_HelloRequest[]
    end
end
function Base.getproperty(obj::HelloRequest, name::Symbol)
    if name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

mutable struct HelloReply <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function HelloReply(; kwargs...)
        obj = new(meta(HelloReply), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        return obj
    end
end # mutable struct HelloReply
const __meta_HelloReply = Ref{ProtoMeta}()
function meta(::Type{HelloReply})
    ProtoBuf.metalock() do
        if !isassigned(__meta_HelloReply)
            __meta_HelloReply[] = target = ProtoMeta(HelloReply)
            allflds = Pair{Symbol,Union{Type,String}}[:message => AbstractString]
            meta(
                target,
                HelloReply,
                allflds,
                ProtoBuf.DEF_REQ,
                ProtoBuf.DEF_FNUM,
                ProtoBuf.DEF_VAL,
                ProtoBuf.DEF_PACK,
                ProtoBuf.DEF_WTYPES,
                ProtoBuf.DEF_ONEOFS,
                ProtoBuf.DEF_ONEOF_NAMES,
            )
        end
        __meta_HelloReply[]
    end
end
function Base.getproperty(obj::HelloReply, name::Symbol)
    if name === :message
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

# service methods for Greeter
const _Greeter_methods = MethodDescriptor[
MethodDescriptor("SayHello", 1, HelloRequest, HelloReply)
] # const _Greeter_methods
const _Greeter_desc = ServiceDescriptor("helloworld.Greeter", 1, _Greeter_methods)

Greeter(impl::Module) = ProtoService(_Greeter_desc, impl)

mutable struct GreeterStub <: AbstractProtoServiceStub{false}
    impl::ProtoServiceStub
    GreeterStub(channel::ProtoRpcChannel) = new(ProtoServiceStub(_Greeter_desc, channel))
end # mutable struct GreeterStub

mutable struct GreeterBlockingStub <: AbstractProtoServiceStub{true}
    impl::ProtoServiceBlockingStub
    GreeterBlockingStub(channel::ProtoRpcChannel) = new(ProtoServiceBlockingStub(_Greeter_desc, channel))
end # mutable struct GreeterBlockingStub

SayHello(stub::GreeterStub, controller::ProtoRpcController, inp, done::Function) =
    call_method(stub.impl, _Greeter_methods[1], controller, inp, done)
SayHello(stub::GreeterBlockingStub, controller::ProtoRpcController, inp) =
    call_method(stub.impl, _Greeter_methods[1], controller, inp)

export HelloRequest, HelloReply, Greeter, GreeterStub, GreeterBlockingStub, SayHello
