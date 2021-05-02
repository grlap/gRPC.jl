module gRPC

import ProtoBuf: call_method

using Nghttp2
using ProtoBuf
using Sockets

export gRPCChannel, gRPCController
export handle_request, call_method

"""
    gRPC channel.
"""
mutable struct gRPCChannel <: ProtoRpcChannel
    session::Http2ClientSession

    function gRPCChannel(session::Http2ClientSession)
        return new(session)
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

#const gRPC_Default_Request = [
#    ":method" => "POST",
#    ":path" => "/MlosAgent.ExperimentManagerService/Echo",
#    ":authority" => "localhost:5000",
#    ":authority" => "localhost",
#    ":scheme" => "http",
#    "content-type" => "application/grpc",
#    "user-agent" => "grpc-dotnet/2.29.0.0",
#    "grpc-accept-encoding" => "identity,gzip",
#    "te" => "trailers"]


"""
    Deserialize the instance of the proto object from the stream.
"""
function deserialize_object!(io::IO, instance::ProtoType)
    compressed = read(io, UInt8)
    data_len = ntoh(read(io, UInt32))

    readproto(io, instance)
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
    request_stream::Http2Stream = recv(http2_server_session)
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

    compressed = read(request_stream, UInt8)
    datalen = ntoh(read(request_stream, UInt32))
    @show compressed, datalen, request_type

    # TODO
    # Limit the steam, should be in bghttp2
    #iob = IOBuffer(read(request_stream, datalen))
    #println("-> before deserialize")
    #seek(iob, 0)
    readproto(request_stream, request_argument)

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

"""
    Client request.
"""
function call_method(channel::ProtoRpcChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::ProtoRpcController, request)
    path = "/" * service.name * "/" * method.name
    headers = [":method" => "POST",
               ":path" => path,
               ":authority" => "localhost:5000",
               ":scheme" => "http",
               "user-agent" => "grpc-python/1.31.0 grpc-c/11.0.0 (windows; chttp2)",
               "accept-encoding" => "identity,gzip",
               "content-type" => "application/grpc",
               "grpc-accept-encoding" => "identity,deflate,gzip",
               "te" => "trailers"]

    io = gRPC.serialize_object(request)

    stream1 = submit_request(
        channel.session,
        io,
        headers)

    response_type = get_response_type(method)
    response = response_type()

    gRPC.deserialize_object!(stream1, response)

    return response
end

end # module gRPC
