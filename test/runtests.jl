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

import ProtoBuf: call_method

using Distributed
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
    println("submited 2")

    response_type = get_response_type(method)
    response = response_type()

    println("reading response")
    respose_data = read_all(stream1)

    iob = IOBuffer(respose_data)

    gRPC.deserialize_object!(iob, response)

    return response
end


function process(proto_service::ProtoService)
    println("process $(proto_service)")
end

"""
    Calling into python.
"""
function python_client()
    println("call_python")

    # Calling from gRPC.jl/test.
    py"""
    import threading
    def hello_from_module(name: str) -> threading.Thread:
        #import python_test.mymodule.server as server
        #server.serve()

        import python_test.mymodule.client as cl
        #cl.run()

        t = threading.Thread(target = cl.run)
        t.start()

        return t
    """

    x = py"hello_from_module"("Julia")
    @show x
    return x
end

function wait_for_thread(thread::PyObject)
    py"""
    import threading
    def wait_for_thread(t: threading.Thread) -> str:
        t.join()
        return "OK"
    """

    x = py"wait_for_thread"(thread)
    @show x

end

function python_server()
    println("python_server")

    # Calling from gRPC.jl/test.
    py"""
    def hello_from_module(name: str) -> str:
        import python_test.mymodule.mymodule as mm

        import python_test.mymodule.server as server
        server.serve()

        # mm.hello_world(name)
        return "abc"
    """

    x = py"hello_from_module"("Julia")
    @show x
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

    controller = gRPCController()
    route_guide_proto_service::ProtoService = RouteGuideTestHander.routeguide.RouteGuide(RouteGuideTestHander)

    println("=> before accept")

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

# Verifies calling into Nghttp library.
@testset "gRPC " begin

    # Example how to use PyCall
    py_sys = pyimport("sys")
    @show py_sys.version
    py_os = pyimport("os")
    @show py_os.__file__


    # Configure python path for the local imports.
    println(@__DIR__)
    # Both are required for proper imports
    pushfirst!(PyVector(pyimport("sys")."path"), @__DIR__)
    pushfirst!(PyVector(pyimport("sys")."path"), "$(@__DIR__)/python_test/mymodule")
    #call_python()


    # Server

    println("1")
    t1 = @task begin
        python_client()
    end

    t3 = @task begin
        client_call()
    end

    t2 = @task begin
        server_call()
    end

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

    println("Hello after")

    @test true
end


