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
"""
module RouteGuideTestHandler
using gRPC
using ResumableFunctions
include("proto/proto_jl_out/routeguide.jl")

const GRPC_SERVER = Ref{gRPCServer}()

function GetFeature(point::routeguide.Point)
    println("->GetFeature")
    @show point
    feature = routeguide.Feature()
    feature.name = "from_julia"
    feature.location = point
    return feature
end

@resumable function ListFeatures(rect::routeguide.Rectangle)
    println("ListFeatures")
    feature = routeguide.Feature()
    feature.name = "from_julia"
    @yield feature

    println("ListFeatures")
    feature = routeguide.Feature()
    feature.name = "from_julia"
    @yield feature

    feature = routeguide.Feature()
    feature.name = "from_julia_1"
    @yield feature

    feature = routeguide.Feature()
    feature.name = "from_julia_2"
    @yield feature
    return nothing
end

function RouteEcho(route_note::routeguide.RouteNote)
    println("->RouteEcho")
    @show route_note
    res = routeguide.RouteNote()
    res.message = "from_julia"
    return res
end

function TerminateServer(empty::routeguide.Empty)
    println("->TerminateServer")
    GRPC_SERVER.x.is_running = false
    return routeguide.Empty()
end

end # module RouteGuideTestHandler

function server_call(socket)
    println("[[$(Threads.threadid())]] => server_call")

    controller = gRPCController()

    server = gRPCServer()
    RouteGuideTestHandler.GRPC_SERVER.x = server

    ## TODO store routes in the server.
    route_guide_proto_service::ProtoService = RouteGuideTestHandler.routeguide.RouteGuide(RouteGuideTestHandler)

    println("[[$(Threads.threadid())]] => before accept ")

    accepted_socket = accept(socket)
    println("<= after accept")

    nghttp2_server_session = Nghttp2.from_accepted(accepted_socket)
    println("4")

    while server.is_running
        handle_request(nghttp2_server_session, controller, route_guide_proto_service)
        println("5")
    end

    println("6")
    return nothing
end

function client_call()
    println("connect_1")
    controller = gRPCController()
    tcp_connection = connect(50200)
    grpc_channel = gRPCChannel(Nghttp2.open(tcp_connection))

    routeGuide = routeguide.RouteGuideBlockingStub(grpc_channel)

    # Get feature.
    println("client_call-1")
    in_point = routeguide.Point()
    in_point.latitude = 1
    in_point.longitude = 2

    for n in 1:10
        result = routeguide.GetFeature(routeGuide, controller, in_point)
    end

    # List features.
    in_rect = routeguide.Rectangle()

    list_features = routeguide.ListFeatures(routeGuide, controller, in_rect)
    for feature in list_features
        println("===[]===")
        @show typeof(feature)
        @show feature
    end

    # Terminate the server.
    _ = routeguide.TerminateServer(routeGuide, controller, routeguide.Empty())

    return nothing
end

function client_call_2()
    println("connect_2")
    controller = gRPCController()
    tcp_connection = connect(50200)
    @show tcp_connection
    grpc_channel = gRPCChannel(Nghttp2.open(tcp_connection))

    routeGuide = routeguide.RouteGuideBlockingStub(grpc_channel)

    in_rect = routeguide.Rectangle()

    result = routeguide.ListFeatures(routeGuide, controller, in_rect)
    for el in result
        println("===[]===")
        @show el
    end

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

    f1 = @async server_call(socket)

    fetch(f2)
    fetch(f1)

    close(socket)

    return nothing
end

function test2()
    socket = listen(50200)

    # listen(), then pass the socket
    f1 = @spawnat 1 server_call(socket)

    f2 = @spawnat 1 client_call()

    fetch(f1)
    fetch(f2)

    close(socket)
    return nothing
end

function test3()
    f2 = @spawnat 2 python_server()

    wait_for_server(UInt16(50200))

    f1 = @spawnat 1 client_call()

    fetch(f1)
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
