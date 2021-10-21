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
include("proto/proto_jl_out/routeguide.jl")
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

    pip_os.main(["install", "protobuf==3.18.1"])
    pip_os.main(["install", "grpcio==1.41.0"])
    pip_os.main(["install", "grpcio-tools==1.41.0"])
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
    include("proto/proto_jl_out/routeguide.jl")

    const GRPC_SERVER = Ref{gRPCServer}()

    function GetFeature(point::routeguide.Point)
        println("[Server]->GetFeature")

        feature = routeguide.Feature()
        feature.name = "from_julia"
        feature.location = point
        return feature
    end

    @resumable function ListFeatures(rect::routeguide.Rectangle)
        println("[Server]->ListFeatures")

        feature = routeguide.Feature()
        feature.name = "enumerate_from_julia_1"
        @yield feature

        feature = routeguide.Feature()
        feature.name = "enumerate_from_julia_2"
        @yield feature

        feature = routeguide.Feature()
        feature.name = "enumerate_from_julia_3"
        @yield feature

        feature = routeguide.Feature()
        feature.name = "enumerate_from_julia_4"
        @yield feature
    end

    function RouteEcho(route_note::routeguide.RouteNote)
        println("[Server]->RouteEcho")

        res = routeguide.RouteNote()
        res.message = "from_julia"
        return res
    end

    @resumable function RouteChat(routes::ReceivingStream{routeguide.RouteNote})
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
    route_node = routeguide.RouteNote()
    route_node.message = "Julia Client 1"
    @yield route_node

    route_node = routeguide.RouteNote()
    route_node.message = "Julia Client 2"
    @yield route_node

    route_node = routeguide.RouteNote()
    route_node.message = "Julia Client 3"
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

    return nothing
end

function client_call()
    println("connect_1")
    controller = gRPCController()
    tcp_stream = connect(50200)

    #
    #ssl_ctx = OpenSSL.SSLContext(OpenSSL.TLSv12ClientMethod())
    #result = OpenSSL.ssl_set_options(ssl_ctx, OpenSSL.SSL_OP_NO_COMPRESSION | OpenSSL.SSL_OP_NO_TLSv1_2)
    #result = OpenSSL.ssl_set_alpn(ssl_ctx, OpenSSL.UPDATE_HTTP2_ALPN)

    #ssl_stream = SSLStream(ssl_ctx, tcp_stream, tcp_stream)

    # TODO expose connect
    #result = connect(ssl_stream)

    client_session = Nghttp2.open(tcp_stream)
    #
    grpc_channel = gRPCChannel(client_session)

    routeGuide = routeguide.RouteGuideBlockingStub(grpc_channel)

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
    in_point = routeguide.Point()
    in_point.latitude = 1
    in_point.longitude = 2

    for n in 1:10
        result = routeguide.GetFeature(routeGuide, controller, in_point)
    end

    # List features.
    println("=> client_call.ListFeatures")
    in_rect = routeguide.Rectangle()

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
    socket = listen(50200)
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
    socket = listen(50200)

    f2 = @spawnat 2 python_client()

    server_call(socket)

    fetch(f2)

    close(socket)

    return nothing
end

function test2()
    socket = listen(50200)

    # listen(), then pass the socket
    f1 = @spawnat 1 server_call(socket)

    client_call()

    fetch(f1)

    close(socket)
    return nothing
end

function test3()
    f2 = @spawnat 2 python_server(private_key_pem, public_key_pem)

    wait_for_server(UInt16(50200))

    client_call()

    fetch(f2)

    return nothing
end

@testset "Python client - Julia server" begin
    test1()
    @test true
end

@testset "Julia server and client" begin
    test2()
    @test true
end

@testset "Python server - Julia client" begin
    test3()
    @test true
end
