module gRPC

import ProtoBuf: call_method

using CodecZlib
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
struct gRPCController <: ProtoRpcController end

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

# https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md

"""
    gRPC Http2 responces.
"""
const DEFAULT_STATUS_200 = [":status" => "200", "content-type" => "application/grpc", "grpc-encoding" => "gzip"]
const DEFAULT_GZIP_ENCRYPTION_STATUS_200 = [":status" => "200", "content-type" => "application/grpc", "grpc-encoding" => "gzip"]
const DEFAULT_TRAILER = ["grpc-status" => "0"]

"""
    Deserialize the instance of the proto object from the stream.
"""
function deserialize_object!(io::IO, instance::ProtoType)
    println("[->] deserialize_object!")
    compressed = read(io, UInt8)
    data_len = ntoh(read(io, UInt32))
    println("compressed: $(compressed) data_len: $(data_len)")

    if compressed == 1
        io = GzipDecompressorStream(io)
    end

    readproto(io, instance)

    if compressed == 1
        finalize(io)
    end

    return nothing
end

"""
    Serialize the instance of the proto object into the stream.
"""
function serialize_object(instance::ProtoType)
    iob = IOBuffer()
    # No compresion.
    write(iob, UInt8(1))

    iob_proto = IOBuffer()
    data_len = writeproto(iob_proto, instance)
    seek(iob_proto, 0)

    compressed = transcode(GzipCompressor, read(iob_proto))
    @show compressed

    @show compressed

    write(iob, hton(UInt32(length(compressed))))
    write(iob, compressed)

    @show iob

    # Placeholder for the serialized object length.
    #data_len = writeproto(iob, instance)
    #@show  length(read(compressed_stream))
    #write(iob, hton(UInt32(0)))
    #data_len = writeproto(iob, instance)
    #seek(iob, 1)
    #write(iob, hton(UInt32(data_len)))


    seek(iob, 0)
    return iob
end

"""
    Process server request.
"""
function handle_request(http2_server_session::Http2ServerSession, controller::gRPCController, proto_service::ProtoService)
    println("[->] handle_request!")

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
    @show sevice_name, method

    request_type = get_request_type(proto_service, method)
    @show request_type
    request_argument = request_type()

    deserialize_object!(request_stream, request_argument)

    response = call_method(proto_service, method, controller, request_argument)
    println("Prepare for response")

    io = serialize_object(response)

    println("-> submit_response")
    return submit_response(request_stream, io, gRPC.DEFAULT_STATUS_200, gRPC.DEFAULT_TRAILER)
end

"""
    Client request.
"""
function call_method(channel::ProtoRpcChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::ProtoRpcController, request)
    path = "/" * service.name * "/" * method.name
    headers = [":method" => "POST", ":path" => path, ":authority" => "localhost:5000", ":scheme" => "http", "user-agent" => "grpc-julia", "accept-encoding" => "identity,gzip",
               "content-type" => "application/grpc", "grpc-accept-encoding" => "identity,deflate,gzip", "te" => "trailers"]

    io = gRPC.serialize_object(request)

    stream1 = submit_request(channel.session, io, headers)

    response_type = get_response_type(method)
    response = response_type()

    deserialize_object!(stream1, response)

    return response
end

end # module gRPC
