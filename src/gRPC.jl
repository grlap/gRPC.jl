module gRPC

using Nghttp2
using ProtoBuf
using Sockets

export gRPCChannel, gRPCController
export handle_request

"""
    gRPC channel.
"""
mutable struct gRPCChannel <: ProtoRpcChannel
    session::Http2ClientSession
    stream_id::UInt32

    function gRPCChannel(session::Http2ClientSession)
        return new(session, 0)
    end
end

"""
    gRPCController.
"""
struct gRPCController <: ProtoRpcController
end

"""
    gRPC server implementation
"""

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
    gRPC Http2 responces.
"""
const DEFAULT_STATUS_200 = [":status" => "200", "content-type" => "application/grpc"]
const DEFAULT_TRAILER = ["grpc-status" => "0"]

const gRPC_Default_Request = [
    ":method" => "POST",
    ":path" => "/MlosAgent.ExperimentManagerService/Echo",
#    ":authority" => "localhost:5000",
    ":authority" => "localhost",
    ":scheme" => "http",
    "content-type" => "application/grpc",
    "user-agent" => "grpc-dotnet/2.29.0.0",
    "grpc-accept-encoding" => "identity,gzip",
    "te" => "trailers"]


function read_all(io::IO)::Vector{UInt8}
    # Create IOBuffer and copy chunks until we read eof.
    result_stream = IOBuffer()

    while !eof(io)
        buffer_chunk = read(io)
        write(result_stream, buffer_chunk)
    end

    seekstart(result_stream)
    return result_stream.data
end

"""
    Deserialize the instance of the proto object from the stream.
"""
function deserialize_object!(iob::IOBuffer, instance::ProtoType)
    compressed = read(iob, UInt8)
    datalen = ntoh(read(iob, UInt32))

    # TODO limit the input buffer size
    iob = IOBuffer(read(iob, datalen))
    seek(iob, 0)
    readproto(iob, instance)
end

"""
    Serialize the instance of the proto object into the stream.
"""
function serialize_object(instance::ProtoType)
    iob = IOBuffer()
    # No compresion.
    write(iob, UInt8(0))
    # Placeholder for the serialized object length.
    write(iob, hton(UInt32(0)))
    data_len = writeproto(iob, instance)
    seek(iob, 1)
    write(iob, hton(UInt32(data_len)))
    seek(iob, 0)
    return iob
end

"""
    Process server request.
"""
function handle_request(http2_server_session::Http2ServerSession, controller::gRPCController, proto_service::ProtoService)
    request_stream = recv(http2_server_session)
    @show request_stream.headers

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
    @show method

    request_type = get_request_type(proto_service, method)
    @show request_type
    request_argument = request_type()

    request_data = read_all(request_stream)
    @show request_data

    iob = IOBuffer(request_data)
    compressed = read(iob, UInt8)
    datalen = ntoh(read(iob, UInt32))
    @show compressed, datalen, request_type

    # TODO
    # Limit the steam, should be in bghttp2
    iob2 = IOBuffer(read(iob, datalen))
    println("-> before deserialize")
    seek(iob2, 0)
    readproto(iob2, request_argument)

    response = call_method(proto_service, method, controller, request_argument)
    println("Prepare for response")

    io = serialize_object(response)

    println("-> submit_response")
    submit_response(
        request_stream,
        io,
        gRPC.DEFAULT_STATUS_200,
        gRPC.DEFAULT_TRAILER)
end


end # module gRPC
