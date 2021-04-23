module gRPC

using Nghttp2
using ProtoBuf
using Sockets

export gRPCChannel, gRPCController

"""
    gRPC channel.
"""
mutable struct gRPCChannel <: ProtoRpcChannel
    session::Http2ClientSession
    stream_id::UInt32

    function gRPCChannel(io::IO)
        session = Nghttp2.open(io)

        return new(session, 0)
    end
end

"""
    gRPCController.
"""
struct gRPCController <: ProtoRpcController
end


const gRPC_Default_Status_200 = [":status" => "200", "content-type" => "application/grpc"]
const gRPC_Defautl_Trailer = ["grpc-status" => "0"]

const gRPC_Default_Request = [
    ":method" => "POST",
    ":path" => "/MlosAgent.ExperimentManagerService/Echo",
    ":authority" => "localhost:5000",
    ":scheme" => "http",
    "content-type" => "application/grpc",
    "user-agent" => "grpc-dotnet/2.29.0.0",
    "grpc-accept-encoding" => "identity,gzip",
    "te" => "trailers"]

greet() = print("Hello World!")

end # module
