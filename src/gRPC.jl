module gRPC

import ProtoBuf: call_method

using BitFlags
using CodecZlib
using Nghttp2
using ProtoBuf
using Sockets

export gRPCChannel, gRPCController, gRPCServer
export SerializeStream, DeserializeStream
export handle_request, call_method

"""
    gRPC status error codes.

    https://grpc.github.io/grpc/core/md_doc_statuscodes.html
"""
@enum(StatusCode::Int32,
    # Not an error; returned on success.
    STATUS_OK = 0,
    # The operation was cancelled, typically by the caller. 
    STATUS_CANCELLED = 1,
    # Unknown error. For example, this error may be returned when a Status value received from
    # another address space belongs to an error space that is not known in this address space.
    STATUS_UNKNOWN = 2,
    # The client specified an invalid argument.
    STATUS_INVALID_ARGUMENT = 3,
    # The deadline expired before the operation could complete.
    STATUS_DEADLINE_EXCEEDED = 4,
    # Some requested entity (e.g., file or directory) was not found.
    STATUS_NOT_FOUND = 5,
    # The entity that a client attempted to create (e.g., file or directory) already exists.
    STATUS_ALREADY_EXISTS = 6,
    # The caller does not have permission to execute the specified operation.
    # PERMISSION_DENIED must not be used for rejections caused by exhausting some resource.
    STATUS_PERMISSION_DENIED = 7,
    # Some resource has been exhausted, perhaps a per-user quota, or perhaps the entire file system is out of space.
    STATUS_RESOURCE_EXHAUSTED = 8,
    # The operation was rejected because the system is not in a state required for the operation's execution.
    STATUS_FAILED_PRECONDITION = 9,
    # The operation was aborted, typically due to a concurrency issue such as a sequencer check failure or transaction abort.
    STATUS_ABORTED = 10,
    # The operation was attempted past the valid range.
    STATUS_OUT_OF_RANGE = 11,
    # The operation is not implemented or is not supported/enabled in this service.
    STATUS_UNIMPLEMENTED = 12,
    # Internal errors. This means that some invariants expected by the underlying system have been broken.
    # This error code is reserved for serious errors. 
    STATUS_INTERNAL = 13,
    # The service is currently unavailable. This is most likely a transient condition,
    # which can be corrected by retrying with a backoff.
    # Note that it is not always safe to retry non-idempotent operations.
    STATUS_UNAVAILABLE = 14,
    # Unrecoverable data loss or corruption.
    STATUS_DATA_LOSS = 15,
    # The request does not have valid authentication credentials for the operation.
    STATUS_UNAUTHENTICATED = 16)

const STATUS_CODES = Dict(string(Int(i)) => i for i in instances(StatusCode))

"""
    gRPC error.
"""
struct gRPCError <: Exception
    status_code::StatusCode
    msg::AbstractString

    gRPCError(status_code::StatusCode, msg::AbstractString) = new(status_code, msg)
end

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
    proto_services::Dict{String,ProtoService}
    is_running::Bool

    gRPCServer(routes::Dict{String,ProtoService}) = new(routes, true)
end

"""
    gRPC Controller.
"""
struct gRPCController <: ProtoRpcController end

# https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md

"""
    gRPC Http2 responces.
"""
const DEFAULT_STATUS_200 = [
    ":status" => "200",
    "content-type" => "application/grpc",
    "grpc-encoding" => "gzip"]

const DEFAULT_GZIP_ENCRYPTION_STATUS_200 = [
    ":status" => "200",
    "content-type" => "application/grpc",
    "grpc-encoding" => "gzip"]

const DEFAULT_TRAILER = ["grpc-status" => "0"]

"""
    Serialize a collection of proto objects into a IO stream.
"""
mutable struct SerializeStream <: IO
    itr::Base.Iterators.Enumerate
    next::Any
    buffer::IOBuffer
    eof::Bool

    SerializeStream(itr) = new(itr, iterate(itr), IOBuffer(), false)
end

function internal_read(serialize_stream::SerializeStream)::Bool
    if serialize_stream.eof
        # No more elements available.
        return false
    end

    if !isnothing(serialize_stream.next)
        (i, state) = serialize_stream.next
        (_, element) = i

        # Write to the buffer.
        iob = serialize_object(element)

        current_position = position(serialize_stream.buffer)
        seekend(serialize_stream.buffer)
        write(serialize_stream.buffer, iob)
        seek(serialize_stream.buffer, current_position)

        # Get the next element from the iterator.
        serialize_stream.next = iterate(serialize_stream.itr, state)
    else
        serialize_stream.eof = true
    end

    return !serialize_stream.eof
end

function ensure_in_buffer(serialize_stream::SerializeStream, nb::Integer)
    should_read = true

    # Process the enumeration until there is no more elements available in the collection.
    while should_read
        if bytesavailable(serialize_stream.buffer) >= nb || serialize_stream.eof
            should_read = false
        end

        if should_read && internal_read(serialize_stream)
            continue
        end

        # The read stopped.
        break
    end
end

Base.eof(serialize_stream::SerializeStream)::Bool = serialize_stream.eof && eof(serialize_stream.buffer)

function Base.read(serialize_stream::SerializeStream, nb::Integer)::Vector{UInt8}
    ensure_in_buffer(serialize_stream, nb)

    return read(serialize_stream.buffer, nb)
end

function Base.read(serialize_stream::SerializeStream, ::Type{UInt8})
    ensure_in_buffer(serialize_stream, 1)

    return read(serialize_stream.buffer, UInt8)
end

"""
    Deserialize a collection of proto objects from the IO stream.
"""
struct DeserializeStream{T} <: AbstractChannel{T}
    io::IO

    function DeserializeStream{T}() where {T<:ProtoType}
        return new(devnull)
    end

    function DeserializeStream{T}(io::IO) where {T<:ProtoType}
        return new(io)
    end
end

function Base.Iterators.Enumerate{T}() where {T<:ProtoType}
    return DeserializeStream{T}()
end

function Base.iterate(stream::DeserializeStream{T}, s=nothing) where {T<:ProtoType}
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

    data_length = ntoh(read(io, UInt32))

    instance::T = T()

    if data_length != 0
        io = IOBuffer(read(io, data_length))

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
    data_length = ntoh(read(io, UInt32))

    if data_length != 0
        io = IOBuffer(read(io, data_length))

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
    deserialize_stream = DeserializeStream{T}(io)
    return deserialize_stream
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
    data_length = writeproto(iob, instance)
    seek(iob, 1)
    write(iob, hton(UInt32(data_length)))

    #
    seek(iob, 0)
    return iob
end

function serialize_object(instances)::IO
    serialize_stream = SerializeStream(enumerate(instances))
    return serialize_stream
end

"""
    Process server request.
"""
function handle_request(http2_server_session::Http2ServerSession, controller::gRPCController, server::gRPCServer)
    request_stream::Http2Stream = recv(http2_server_session)

    headers = request_stream.headers

    method = headers[":method"]
    path = headers[":path"]
    path_components = split(path, "/"; keepempty=false)

    if length(path_components) != 2
        # Missing or invalid path in request's header.
        return nothing
    end

    service_name, method_name = path_components

    proto_service::ProtoService = server.proto_services[service_name]

    method = find_method(proto_service, method_name)

    request_type = get_request_type(proto_service, method)

    request_argument = deserialize_object(request_stream, request_type)

    response = call_method(proto_service, method, controller, request_argument)

    io = serialize_object(response)

    return submit_response(request_stream, io, DEFAULT_STATUS_200, DEFAULT_TRAILER)
end

"""
    Client request.
"""
function call_method(
    channel::ProtoRpcChannel,
    service::ServiceDescriptor,
    method::MethodDescriptor,
    controller::ProtoRpcController,
    request)
    path = "/" * service.name * "/" * method.name
    headers = [
        ":method" => "POST",
        ":path" => path,
        ":authority" => "localhost:5000",
        ":scheme" => "http",
        "user-agent" => "grpc-julia",
        "accept-encoding" => "identity,gzip",
        "content-type" => "application/grpc",
        "grpc-accept-encoding" => "identity,deflate,gzip",
        "te" => "trailers"]

    iob = gRPC.serialize_object(request)

    response_stream = submit_request(channel.session, iob, headers)

    response_status_code::StatusCode = STATUS_OK

    # Check grps-status if it is available.
    if haskey(response_stream.headers, "grpc-status")
        grpc_status = response_stream.headers["grpc-status"]

        # Get the response code.
        if haskey(STATUS_CODES, grpc_status)
            response_status_code = STATUS_CODES[grpc_status]
        else
            # Server returned an invalid responose code.
            response_status_code = STATUS_UNKNOWN
        end
    end

    if response_status_code != STATUS_OK
        local response_message::String

        if haskey(response_stream.headers, "grpc-message")
            response_message = response_stream.headers["grpc-message"]
        else
            # Server did not include a response in the message.
            response_message = "unknown"
        end

        throw(gRPCError(response_status_code, response_message))
    end

    response_type = get_response_type(method)

    instance = deserialize_object(response_stream, response_type)

    return instance
end

end # module gRPC
