"""

    Julia <-> Julia does not work
    incorrectly pass the object...

    on

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
using ProtoBuf
using PyCall
using ResumableFunctions
using Sockets
using Test

# Include protobuf codegen files.
include("proto/proto_jl_out/routeguide.jl")

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
    pip_os.main(["install", "protobuf==3.15.8"])
    pip_os.main(["install", "grpcio"])
    pip_os.main(["install", "grpcio-tools"])
    return nothing
end

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

    server = gRPCServer(Dict("routeguide.RouteGuide" => RouteGuideTestHandler.routeguide.RouteGuide(RouteGuideTestHandler)))
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
    tcp_connection = connect(50200)
    grpc_channel = gRPCChannel(Nghttp2.open(tcp_connection))

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
    f2 = @spawnat 2 python_server()

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

# Verifies calling into Nghttp library.
@testset "gRPC " begin
    # Example how to use PyCall
    #py_sys = pyimport("sys")
    #@show py_sys.version
    #py_os = pyimport("os")
    #@show py_os.__file__

    # Configure python path for the local imports.
    #println(@__DIR__)
    # Both are required for proper imports
    #pushfirst!(PyVector(pyimport("sys")."path"), @__DIR__)
    #pushfirst!(PyVector(pyimport("sys")."path"), "$(@__DIR__)/python_test/mymodule")
    #call_python()

    #@show Threads.nthreads()

    # Server
    # import Base.Threads.@spawn
    # s1 = @spawn server_call()
    # s2 = @spawn python_client()
    #import Base.Threads.@spawn
    #@spawn python_client()
    #@spawn server_call()
    # f1=remotecall(server_call, 2)
    # f2=remotecall(python_client, 3)

    #f2 = @spawnat 2 python_client()
    #fetch(f2)

    #println("1")
    #t1 = @task begin
    #python_client()
    #end

    #t3 = @task begin
    #client_call()
    #end

    ###"""
    #t2 = @task begin
    #server_call()
    #end
    #schedule(t2);
    # """

    #println("s1")
    #schedule(t2);
    #println("s2")
    #schedule(t1);
    #println("s3")

    #wait(t2)
    #wait(t1)

    #stream = recv(server_session)
    #@show stream

    #send_buffer = IOBuffer(read(stream))
    #@show send_buffer

    #send(http2_session,
    #stream_id,
    #send_buffer,
    #gRPC.DEFAULT_STATUS_200)
    #"""

    #test1()

    #test2()

    #f2 = @spawnat 2 python_client()
    #println("Hello after")

    #@test true
end
