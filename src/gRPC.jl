module gRPC

import ProtoBuf: call_method

using CodecZlib
using Nghttp2
using ProtoBuf
using Sockets

export gRPCChannel, gRPCController, gRPCServer
export SendingStream, ReceivingStream
export handle_request, call_method

"""
    gRPC channel.
"""
mutable struct gRPCChannel <: ProtoRpcChannel
    session::Http2ClientSession

    gRPCChannel(session::Http2ClientSession) = new(session)
end

"""
    gRPC Server implementation.
"""
mutable struct gRPCServer
    is_running::Bool

    gRPCServer() = new(true)
end

#mutable struct gRPCServer
#    sock::TCPServer
#    services::Dict{String, ProtoService}
#    run::Bool

#    gRPCServer(services::Tuple{ProtoService}, ip::IPv4, port::Integer) =
#        gRPCServer(services, listen(ip, port))
#    gRPCServer(services::Tuple{ProtoService}, port::Integer) =
#        gRPCServer(services, listen(port))
#    function gRPCServer(services::Tuple{ProtoService}, sock::TCPServer)
#        svcdict = Dict{String,ProtoService}()
#        for svc in services
#            svcdict[svc.desc.name] = svc
#        end
#        new(sock, svcdict, true)
#    end
#end

"""
    gRPC Controller.
"""
struct gRPCController <: ProtoRpcController end

# https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md

"""
    gRPC Http2 responces.
"""
const DEFAULT_STATUS_200 = [":status" => "200", "content-type" => "application/grpc", "grpc-encoding" => "gzip"]
const DEFAULT_GZIP_ENCRYPTION_STATUS_200 = [":status" => "200", "content-type" => "application/grpc", "grpc-encoding" => "gzip"]
const DEFAULT_TRAILER = ["grpc-status" => "0"]

mutable struct SendingStream <: IO
    itr::Base.Iterators.Enumerate
    next::Any
    buffer::IOBuffer
    eof::Bool

    SendingStream(itr) = new(itr, iterate(itr), IOBuffer(), false)
end

function internal_read(sending_stream::SendingStream)::Bool
    if sending_stream.eof
        # No more elements available.
        return false
    end

    if !isnothing(sending_stream.next)
        (i, state) = sending_stream.next
        (_, element) = i

        # Write to the buffer.
        iob = serialize_object(element)
        seekend(sending_stream.buffer)
        write(sending_stream.buffer, iob)
        seek(sending_stream.buffer, 0)

        # Get the next element from the iterator.
        sending_stream.next = iterate(sending_stream.itr, state)
    else
        sending_stream.eof = true
    end

    return !sending_stream.eof
end

function ensure_in_buffer(sending_stream::SendingStream, nb::Integer)
    should_read = true

    # TODO comment
    # Process the enumeration until there is no more available data in HTTP2 stream.
    while should_read
        if bytesavailable(sending_stream.buffer) >= nb || sending_stream.eof
            should_read = false
        end

        if should_read && internal_read(sending_stream)
            continue
        end

        # Read failed
        break
    end
end

Base.eof(sending_stream::SendingStream)::Bool = sending_stream.eof && eof(sending_stream.buffer)

function Base.read(sending_stream::SendingStream, nb::Integer)::Vector{UInt8}
    ensure_in_buffer(sending_stream, nb)

    return read(sending_stream.buffer, nb)
end

struct ReceivingStream{T} <: AbstractChannel{T}
    io::IO

    function ReceivingStream{T}() where {T<:ProtoType}
        return new(devnull)
    end

    function ReceivingStream{T}(io::IO) where {T<:ProtoType}
        return new(io)
    end
end

function Base.Iterators.Enumerate{T}() where {T<:ProtoType}
    return ReceivingStream{T}()
end

function Base.iterate(stream::ReceivingStream{T}, s=nothing) where {T<:ProtoType}
    io = stream.io

    if eof(io)
        return nothing
    end

    local compressed::Bool
    try
        compressed = read(io, UInt8)
    catch e
        if isa(e, EOFError)
            return nothing
        else
            rethrow()
        end
    end

    data_len = ntoh(read(io, UInt32))

    instance::T = T()

    if data_len != 0
        io = IOBuffer(read(io, data_len))

        if compressed == 1
            io = GzipDecompressorStream(io)
        end

        readproto(io, instance)

        if compressed == 1
            finalize(io)
        end
    end

    return (instance, 1)
end

"""
    Deserialize a proto object instance from the io stream.
"""
function deserialize_object(io::IO, instance_type::Type{T}) where {T<:ProtoType}
    instance = instance_type()
    is_compressed = read(io, UInt8)
    data_len = ntoh(read(io, UInt32))

    if data_len != 0
        io = IOBuffer(read(io, data_len))

        if is_compressed == 1
            io = GzipDecompressorStream(io)
        end

        readproto(io, instance)

        if is_compressed == 1
            finalize(io)
        end
    end

    return instance
end

"""
    Deserialize a stream of proto objects from the io stream.
"""
function deserialize_object(io::IO, ::Type{AbstractChannel{T}}) where {T<:ProtoType}
    results = ReceivingStream{T}(io)
    return results
end

"""
    Serialize the instance of the proto object into the io buffer.
"""
function serialize_object(instance::ProtoType)::IO
    iob = IOBuffer()

    # Compression.
    #    write(iob, UInt8(1))

    #    iob_proto = IOBuffer()
    #    data_len = writeproto(iob_proto, instance)
    #    seek(iob_proto, 0)

    #    compressed = transcode(GzipCompressor, read(iob_proto))
    #    @show compressed

    #    @show compressed

    #    write(iob, hton(UInt32(length(compressed))))
    #    write(iob, compressed)

    #    @show iob

    # No compression
    write(iob, UInt8(0))
    # Placeholder for the serialized object length.
    write(iob, hton(UInt32(0)))
    data_len = writeproto(iob, instance)
    seek(iob, 1)
    write(iob, hton(UInt32(data_len)))

    #
    seek(iob, 0)
    return iob
end

function serialize_object(instances)::IO
    send_stream = SendingStream(enumerate(instances))
    return send_stream

    #iob = IOBuffer()
    # TODO create a new IOStream
    # As a workaround, serialize all the elements
    #println("[->] serialize_object!!!")
    #for (_, instance) in enumerate(instances)
    #    println("[---]")
    #    write(iob, serialize_object(instance))
    #end
    #seek(iob, 0)
    #return iob
end

"""
    Process server request.
"""
function handle_request(http2_server_session::Http2ServerSession, controller::gRPCController, proto_service::ProtoService)
    request_stream::Http2Stream = recv(http2_server_session)

    headers = request_stream.headers
    method = headers[":method"]
    path = headers[":path"]
    path_components = split(path, "/"; keepempty=false)

    if length(path_components) != 2
        # Missing or invalid path in request's header.
        return nothing
    end

    sevice_name, method_name = path_components

    method = find_method(proto_service, method_name)

    request_type = get_request_type(proto_service, method)

    request_argument = deserialize_object(request_stream, request_type)

    response = call_method(proto_service, method, controller, request_argument)

    io = serialize_object(response)

    return submit_response(request_stream, io, gRPC.DEFAULT_STATUS_200, gRPC.DEFAULT_TRAILER)
end

"""
    Client request.
"""
function call_method(channel::ProtoRpcChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::ProtoRpcController, request)
    path = "/" * service.name * "/" * method.name
    headers = [":method" => "POST", ":path" => path, ":authority" => "localhost:5000", ":scheme" => "http", "user-agent" => "grpc-julia", "accept-encoding" => "identity,gzip",
               "content-type" => "application/grpc", "grpc-accept-encoding" => "identity,deflate,gzip", "te" => "trailers"]

    iob = gRPC.serialize_object(request)

    response_stream = submit_request(channel.session, iob, headers)

    response_type = get_response_type(method)

    instance = deserialize_object(response_stream, response_type)

    return instance
end

end # module gRPC
