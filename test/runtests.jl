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
    abstract type AbstractProtoServiceStub{B} end
"""

using Distributed
using gRPC
using Nghttp2
using OpenSSL
using ProtoBuf
using PyCall
using ResumableFunctions
using Sockets
using Test

# Include protobuf codegen files.
include("proto/proto_jl_out/helloworld/helloworld.jl")
include("proto/proto_jl_out/routeguide/routeguide.jl")

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

    #pip_os.main(["uninstall", "grpcio-tools", "-y"])
    #pip_os.main(["uninstall", "grpcio", "-y"])

    pip_os.main(["install", "protobuf==4.21.12"])
    pip_os.main(["install", "grpcio==1.51.0"])
    pip_os.main(["install", "grpcio-tools==1.51.0"])
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
    # Create a worker process, where we run python interpreter.
    addprocs(1)

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
using ResumableFunctions
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
    println("[Server]->RouteChat")

    for route in routes
        println("[Server]::RouteChat receving and sending route")
        @yield route
    end
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

function helloworld_client_call()
    controller = gRPCController()

    socket = connect(40200)

    client_session = Nghttp2.open(socket)

    # Create gRPC channel.
    grpc_channel = gRPCChannel(client_session)

    greeterClient = helloworld.GreeterBlockingStub(grpc_channel)

    hello_request = helloworld.HelloRequest()
    hello_request.name = "Hello from Julia"

    hello_reply = helloworld.SayHello(greeterClient, controller, hello_request)
    @show hello_reply
end

function client_call(port, use_ssl::Bool)
    println("[client_call]: use_ssl:$use_ssl")
    controller = gRPCController()

    local socket::IO

    if use_ssl
        socket = connect(port)
        ssl_ctx = OpenSSL.SSLContext(OpenSSL.TLSClientMethod())
        #OpenSSL.ssl_set_min_protocol_version(ssl_ctx, OpenSSL.TLS1_2_VERSION)
        #result = OpenSSL.ssl_set_options(ssl_ctx, OpenSSL.SSL_OP_NO_SSL_MASK)
        result = OpenSSL.ssl_set_alpn(ssl_ctx, OpenSSL.HTTP2_ALPN)

        socket = SSLStream(ssl_ctx, socket, socket)

        Sockets.connect(socket; require_ssl_verification = false)
    else
        socket = connect(port)
    end

    client_session = Nghttp2.open(socket)

    # Create gRPC channel.
    grpc_channel = gRPCChannel(client_session)

    routeGuide = gRPC.ProtoServiceBlockingStub(routeguide._RouteGuide_desc, grpc_channel)
    #routeGuide = routeguide.RouteGuideBlockingStub(grpc_channel)

    # RouteChat.
    route_nodes = routeguide.RouteChat(routeGuide, controller, ListRouteNotes())
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
        result = routeguide.GetFeature(routeGuide, controller, in_point)
    end

    # List features.
    println("=> client_call.ListFeatures")
    in_rect = routeguide.Rectangle(routeguide.Point(2,2), routeguide.Point(4,5))
    @show in_rect

    list_features = routeguide.ListFeatures(routeGuide, controller, in_rect)
    for feature in list_features
        println("feature.name: $(feature.name)")
    end

    # Terminate the server.
    println("=> client_call.TerminateServer")
    _ = routeguide.TerminateServer(routeGuide, controller, routeguide.Empty())

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

    f2 = @spawnat 2 python_client()

    server_call(socket)

    fetch(f2)

    return nothing
end

function test2()
    socket = listen(40200)

    # listen(), then pass the socket
    f1 = @spawnat 1 server_call(socket)

    client_call(40200, false)

    fetch(f1)

    return nothing
end

function test3()
    f2 = @spawnat 2 python_server(private_key_pem, public_key_pem)

    wait_for_server(UInt16(40500))

    client_call(40500, true)

    fetch(f2)

    return nothing
end

function test4()
    f2 = @spawnat 2 python_server(private_key_pem, public_key_pem)

    wait_for_server(UInt16(40300))

    client_call(40300, false)

    fetch(f2)

    return nothing
end

@testset "Python client - Julia server" begin
    test1()
    @test true
    test1()
    @test true
end

@testset "Julia server and client" begin
    test2()
    @test true
    test2()
    @test true
end

@testset "Secure Python server - Julia client" begin
    test3()
    @test true
    test3()
    @test true
end

@testset "Insecure Python server - Julia client" begin
    test4()
    @test true
    test4()
    @test true
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

#include("test\\runtests.jl")
#f1 = server_call(listen(40200))

#include("test\\runtests.jl")
#client_call(40200, false)

