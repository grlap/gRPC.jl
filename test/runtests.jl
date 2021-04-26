"""

    Julia <-> Julia does not work
    incorrectly pass the object...


    on

    arm64
    ~/miniforge3/bin/python3

    https://betterprogramming.pub/using-python-and-r-with-julia-b7019a3d1420


Final list:
[ ] Http2Stream can read buffer with given length

[ ] On error close the stream

[ ] inner process reads are blocking ...

## Check which process opened the port.
    sudo lsof -nP -i4TCP:50051 | grep LISTEN

[x] gRPC python

[x] find gRPC examples
    gRPC examples:
    git clone -b v1.35.0 https://github.com/grpc/grpc

[ ]
    python -m grpc_tools.protoc -I../../protos --python_out=. --grpc_python_out=. ../../protos/route_guide.proto

    /Users/greg/GitHub/Personal/gRPC.jl/test/proto
    python -m grpc_tools.protoc -I. --grpc_python_out=. route_guide.proto

    python -m grpc_tools.protoc -I./test/proto --grpc_python_out=. route_guide.proto

    Install python gRPC
    python -m pip install grpcio
    python -m pip install grpcio-tools

from grpc.tools import command
    command.build_package_protos(self.distribution.package_dir[''])

    https://pypi.org/project/grpcio-tools/

[ ] Working Python gRPC server/client example.

[ ] Proto.jl

    creates a Service descriptor

    const _RouteGuide_methods = MethodDescriptor[
        MethodDescriptor("GetFeature", 1, Point, Feature),
        MethodDescriptor("ListFeatures", 2, Rectangle, Channel{Feature}),
        MethodDescriptor("RecordRoute", 3, Channel{Point}, RouteSummary),
        MethodDescriptor("RouteChat", 4, Channel{RouteNote}, Channel{RouteNote})
    ] # const _RouteGuide_methods
const _RouteGuide_desc = ServiceDescriptor("routeguide.RouteGuide", 1, _RouteGuide_methods)

RouteGuide(impl::Module) = ProtoService(_RouteGuide_desc, impl)

[ ] Investigate 
    Julia Proto implementation
    abstract type ProtoRpcChannel end
    abstract type ProtoRpcController end
    abstract type AbstractProtoServiceStub{B} end
"""

using Distributed

import ProtoBuf: call_method

using gRPC
using Nghttp2
using ProtoBuf
using PyCall
using Sockets
using Test

# Include protobuf codegen files.
include("proto/proto_jl_out/routeguide.jl")

"""
    Handler.
"""
module RouteGuideTestHander
    include("proto/proto_jl_out/routeguide.jl")

    function GetFeature(point::routeguide.Point)
        println("->GetFeature")
        @show point
        feature = routeguide.Feature()
        feature.name = "from_julia"
        feature.location = point
        return feature
    end
end

function write_request(
    channel::gRPCChannel,
    controller::gRPCController,
    service::ServiceDescriptor,
    method::MethodDescriptor,
    request)
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

    stream_id1 = submit_request(
        channel.session,
        io,
        headers)
    println("submited with stream_id: $(stream_id1)")

    stream1 = recv(channel.session.session)
    return stream1
end



"""
    Client request.
"""
function call_method(channel::ProtoRpcChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::ProtoRpcController, request)
    println("|>internal call_method")
    stream1 = write_request(channel, controller, service, method, request)

    response_type = get_response_type(method)
    response = response_type()

    println(" | reading response")
    gRPC.deserialize_object!(stream1, response)

    return response
end


function process(proto_service::ProtoService)
    println("process $(proto_service)")
end


function client_call()
    println("connect_1")
    controller = gRPCController()
    tcp_connection = connect(5000)
    @show tcp_connection
    grpc_channel = gRPCChannel(Nghttp2.open(tcp_connection))

    routeGuide = routeguide.RouteGuideBlockingStub(grpc_channel)

    in_point = routeguide.Point()
    in_point.latitude = 1
    in_point.longitude = 2

    #for n in 1:10
    result = routeguide.GetFeature(routeGuide, controller, in_point)
    #end
end

function server_call()
    socket = listen(5000)
    server_call(socket)
end

function server_call(socket)
    println("[[$(Threads.threadid())]] => server_call")

    controller = gRPCController()
    route_guide_proto_service::ProtoService = RouteGuideTestHander.routeguide.RouteGuide(RouteGuideTestHander)

    println("[[$(Threads.threadid())]] => before accept ")

    accepted_socket = accept(socket)
    println("<= after accept")

    nghttp2_server_session = Nghttp2.from_accepted(accepted_socket)
    println("4")

    handle_request(nghttp2_server_session, controller, route_guide_proto_service)
    println("5")
end

function test_serialize()

    in_point = routeguide.Point()
    in_point.latitude = 1
    in_point.longitude = 2

    iob = IOBuffer()
    writeproto(iob, in_point)
    seek(iob , 0)
    @show read(iob)

    #out_point = RouteGuideTestHander.routeguide.Point()
    #readproto(iob, out_point)
    #@show out_point
end

"""
    Use python client.
"""
function test1()
    # Create a worker process, where we run python interpreter.
    addprocs(1)

    # Load python wrappers into the worker processes.
    @everywhere include("test/py_helpers.jl")

    socket = listen(5000)

    # listen(), then pass the socket
    f1 = @async server_call(socket)
    # remove sleep
    #sleep(1)

    f2 = @spawnat 2 python_client()

    fetch(f1)
    fetch(f2)

    close(socket)
end

function test2()
    socket = listen(5000)

    # listen(), then pass the socket
    f1 = @spawnat 1 server_call(socket)

    f2 = @spawnat 1 client_call()

    fetch(f1)
    fetch(f2)

    close(socket)
end

# Verifies calling into Nghttp library.
@testset "gRPC " begin

    # Example how to use PyCall
    #py_sys = pyimport("sys")
    #@show py_sys.version
    #py_os = pyimport("os")
    #@show py_os.__file__


    # Configure python path for the local imports.
    println(@__DIR__)
    # Both are required for proper imports
    pushfirst!(PyVector(pyimport("sys")."path"), @__DIR__)
    pushfirst!(PyVector(pyimport("sys")."path"), "$(@__DIR__)/python_test/mymodule")
    #call_python()

@show Threads.nthreads()

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

    println("s1")
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
    println("Hello after")

    @test true
end


