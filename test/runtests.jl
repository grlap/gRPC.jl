"""

    arm64
    ~/miniforge3/bin/python3

    https://betterprogramming.pub/using-python-and-r-with-julia-b7019a3d1420

Final list:
[x] Http2Stream can read buffer with given length

[ ] On error close the stream

[ ] inner process reads are blocking ...

## Check which process opened the port.
    sudo lsof -nP -i4TCP:50051 | grep LISTEN

from grpc.tools import command
    command.build_package_protos(self.distribution.package_dir[''])

    https://pypi.org/project/grpcio-tools/

[x] Working Python gRPC server/client example.

[ ] Investigate 
    Julia Proto implementation
    abstract type ProtoRpcChannel end
    abstract type ProtoRpcController end
"""

using Distributed
using gRPC
using Nghttp2
using OpenSSL
using ProtoBuf
using PyCall
using Semicoroutines
using Sockets
using Test

# Include protobuf codegen files.
module helloworld
import gRPC: grpc_client_call
include("proto/proto_jl_out/helloworld/helloworld_pb.jl")
end

module routeguide
import gRPC: grpc_client_call
include("proto/proto_jl_out/routeguide/route_guide_pb.jl")
end


# Include certificate helper functions.
include("cert_helpers.jl")

"""
    Installs python gRPC modules.

    Equivalent of running the commands:
    python -m pip install grpcio
    python -m pip install grpcio-tools
"""
function python_install_requirements()
    pip_os = pyimport("pip")
    pip_os.main(["list"])

    #pip_os.main(["uninstall", "protobuf", "-y"])
    #pip_os.main(["uninstall", "grpcio-tools", "-y"])
    #pip_os.main(["uninstall", "grpcio", "-y"])

    pip_os.main(["install", "protobuf==4.24.0"])
    pip_os.main(["install", "grpcio==1.57.0"])
    pip_os.main(["install", "grpcio-tools==1.57.0"])
    return nothing
end

private_key_pem, public_key_pem = create_self_signed_certificate()

# Install gRPC modules
python_install_requirements()

"""
    Configures PyCall, adds a new Julia process to handle Python cals.
"""
function configure_pycall()
    println("Configure python [aths]")
    t = rmprocs(2, 3, waitfor=0)
    wait(t)

    # Create a worker process, where we run python interpreter.
    # One for the gRPC server, second for gRPC client.
    #
    addprocs(2)

    # Load python wrappers into the worker processes.
    @everywhere include("py_helpers.jl")
    #@everywhere include("test/py_helpers.jl")
end

# Configure PyCall.
configure_pycall()

"""
    Handler.
    gRPC test server implementation.
"""
module RouteGuideTestHandler
using gRPC
using Semicoroutines
import gRPC: call_method
include("proto/proto_jl_out/routeguide/routeguide.jl")

const GRPC_SERVER = Ref{gRPCServer}()

function GetFeature(point::routeguide.Point)
    println("[Server]->GetFeature")

    feature = routeguide.Feature("from_julia", point)

    return feature
end

@resumable function ListFeatures(rect::routeguide.Rectangle)
    println("[Server]->ListFeatures")

    feature = routeguide.Feature("enumerate_from_julia_1", nothing)
    @yield feature

    feature = routeguide.Feature("enumerate_from_julia_2", nothing)
    @yield feature

    feature = routeguide.Feature("enumerate_from_julia_3", nothing)
    @yield feature

    feature = routeguide.Feature("enumerate_from_julia_4", nothing)
    @yield feature
end

function RouteEcho(route_note::routeguide.RouteNote)
    println("[Server]->RouteEcho")

    res = routeguide.RouteNote(nothing, "from_julia")
    return res
end

@resumable function RouteChat(routes::DeserializeStream{routeguide.RouteNote})
    println("[Server]::RouteChat => Begin")

    for route in routes
        println("[Server]::RouteChat receving and sending route", route)
        @yield route
        println("[Server]::RouteChat after sending route")
    end
    println("[Server]::RouteChat => End")
end

function TerminateServer(empty::routeguide.Empty)
    println("[Server]->TerminateServer")
    GRPC_SERVER.x.is_running = false
    return routeguide.Empty()
end

end # module RouteGuideTestHandler

@resumable function ListRouteNotes()
    route_node = routeguide.RouteNote(nothing, "Julia Client 1")
    @yield route_node

    route_node = routeguide.RouteNote(nothing, "Julia Client 2")
    @yield route_node

    route_node = routeguide.RouteNote(nothing, "Julia Client 3")
    @yield route_node
end

function server_call(socket)
    println("[server_call]::[$(Threads.threadid())]")

    controller = gRPCController()

    server = gRPCServer(
        Dict("routeguide.RouteGuide" => RouteGuideTestHandler.routeguide.RouteGuide(RouteGuideTestHandler))
    )
    RouteGuideTestHandler.GRPC_SERVER.x = server

    accepted_socket = accept(socket)

    nghttp2_server_session = Nghttp2.from_accepted(accepted_socket)

    while server.is_running
        handle_request(nghttp2_server_session, controller, server)
    end

    close(socket)

    return nothing
end

function client_call(port::UInt16, use_ssl::Bool, terminate_server::Bool)
    println("[client_call]: use_ssl:$use_ssl")
    @show use_ssl
    @show terminate_server

    local socket::IO

    if use_ssl
        socket = connect(port)
        ssl_ctx = OpenSSL.SSLContext(OpenSSL.TLSClientMethod())
        #OpenSSL.ssl_set_min_protocol_version(ssl_ctx, OpenSSL.TLS1_2_VERSION)
        #result = OpenSSL.ssl_set_options(ssl_ctx, OpenSSL.SSL_OP_NO_SSL_MASK)
        result = OpenSSL.ssl_set_alpn(ssl_ctx, OpenSSL.HTTP2_ALPN)

        socket = SSLStream(ssl_ctx, socket)

        Sockets.connect(socket; require_ssl_verification = false)
    else
        socket = connect(port)
    end

    println("[client_call]::tcp_connected")

    client_session = Nghttp2.open(socket)

    # Create gRPC channel.
    grpc_channel = gRPCChannel(client_session)

    # RouteChat.
    route_nodes = routeguide.RouteChat(grpc_channel, ListRouteNotes())
    received_count::Int = 0

    for route_node in route_nodes
        received_count = received_count + 1
    end

    @test received_count == length(collect(ListRouteNotes()))

    println("-> route notes.")

    # Get feature.
    println("=> client_call.GetFeature")
    in_point = routeguide.Point(1, 2)

    for n in 1:10
        result = routeguide.GetFeature(grpc_channel, in_point)
    end

    # List features.
    println("=> client_call.ListFeatures")
    in_rect = routeguide.Rectangle(routeguide.Point(2,2), routeguide.Point(4,5))
    @show in_rect

    list_features = routeguide.ListFeatures(grpc_channel, in_rect)
    for feature in list_features
        println("feature.name: $(feature.name)")
    end

    #if terminate_server
        try
            @show "terminate_server"
            _ = routeguide.TerminateServer(grpc_channel, routeguide.Empty())
            @show "terminate_server done"
        catch e
            @show e
        end
    #end

    println("[client_call]::done")

    return nothing
end

function server_call()
    socket = listen(40200)
    server_call(socket)
    return nothing
end

function wait_for_server(port::UInt16)
    connected = false
    while !connected
        connected = try
            connect(port)
            true
        catch e
            println("waiting")
            sleep(1)
            false
        end
    end
end

"""
    Use python client.
"""
function test1()
    socket = listen(40200)

    f2 = @spawnat 3 python_client()

    server_call(socket)

    fetch(f2)

    return nothing
end


function test2()
    socket = listen(40200)

    # listen(), then pass the socket
    f1 = @spawnat 1 server_call(socket)

    client_call(UInt16(40200), false, true)

    fetch(f1)

    return nothing
end


@resumable function enumerate_test_features()
    for i in 1:10
        feature = routeguide.Feature("enumerate_from_julia_$i", nothing)
        @yield feature
    end
end

@testset "SerializeStream" begin
    serialize_stream = SerializeStream(enumerate(enumerate_test_features()))

    deserialize_stream = DeserializeStream{routeguide.Feature}(serialize_stream)

    for (index, value) in enumerate(deserialize_stream)
        @show index, value
    end
end
"""
@testset "Python client - Julia server" begin
    test1()
    @test true
end

@testset "Julia server and client" begin
    test2()
    @test true
end

@testset "Secure Python server - Julia client" begin
    f1 = @spawnat 2 python_server(private_key_pem, public_key_pem)
    @show "waiting"
    wait_for_server(UInt16(40500))
    @show "waiting done"

    client_call(UInt16(40500), true, true)
    @test true

    @show f1

    wait(f1)
end
"""

"""
@testset "Insecure Python server - Julia client" begin
    f1 = @spawnat 2 python_server(private_key_pem, public_key_pem)
    @show "waiting"
    wait_for_server(UInt16(40300))
    @show "waiting done"

    client_call(UInt16(40300), false, true)
    @test true

    wait(f1)

    # Shutdown gRPC server.
    @show workers()
    #t = rmprocs(2, 3, waitfor=0)
    #wait(t)

    @show workers()
end
"""