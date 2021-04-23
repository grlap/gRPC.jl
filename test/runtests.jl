"""

    arm64
    ~/miniforge3/bin/python3

    https://betterprogramming.pub/using-python-and-r-with-julia-b7019a3d1420

## Check which process opened the port.
    sudo lsof -nP -i4TCP:50051 | grep LISTEN

[ ] gRPC python

[ ] find gRPC examples
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

end

# move to common
mutable struct gRPCChannel <: ProtoRpcChannel
    session::Nghttp2.ClientSession
    stream_id::UInt32

    function gRPCChannel()
        tcp_connection = connect("localhost", 50051)
        session = Nghttp2.open(tcp_connection)

        return new(session, 0)
    end
end

struct gRPCController <: ProtoRpcController
end

function to_delimited_message_bytes(msg)
    iob = IOBuffer()
    write(iob, UInt8(0))
    write(iob, hton(UInt32(0)))
    data_len = writeproto(iob, msg)
    seek(iob, 1)
    write(iob, hton(UInt32(data_len)))
    seek(iob, 0)
    return iob
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
               "user-agent" => "grpc-python/1.31.0 grpc-c/11.0.0 (windows; chttp2)",
               "accept-encoding" => "identity,gzip",
               ":authority" => "localhost:50051",
               ":scheme" => "http",
               "content-type" => "application/grpc",
               "grpc-accept-encoding" => "identity,deflate,gzip",
               "te" => "trailers"]
    #trailers = ["grpc-status" => "0"]

#    ":method" => "POST",
#    ":path" => "/MlosAgent.ExperimentManagerService/Echo",
#    ":authority" => "localhost:5000",
#    ":scheme" => "http",
#    "content-type" => "application/grpc",
#    "user-agent" => "grpc-dotnet/2.29.0.0",
#    "grpc-accept-encoding" => "identity,gzip"]

    println("write_request")
    @show path
    @show headers

    io = to_delimited_message_bytes(request)

    stream_id1 = Nghttp2.submit_request(
        channel.session.session,
        io,
        headers)

    println("<--submited_request")
    @show stream_id1
    stream1 = recv(channel.session.session)
    println("<--received stream")

    return stream1

    #channel.stream_id = Session.next_free_stream_identifier(connection)
    #@debug("writing request", stream_id=channel.stream_id)
    #Session.put_act!(connection, Session.ActSendHeaders(channel.stream_id, headers, false))
    #data_buff = to_delimited_message_bytes(request)
    #Session.put_act!(channel.session, Session.ActSendData(channel.stream_id, data_buff, true))
    #@debug("wrote request", stream_id=channel.stream_id, nbytes=length(data_buff))
    nothing
end


function call_method(channel::ProtoRpcChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::ProtoRpcController, request)
    stream1 = write_request(channel, controller, service, method, request)
    @show stream1
    response_type = get_response_type(method)
    response = response_type()

    println("reading response")
    respose_data = read_all(stream1)

    iob = IOBuffer(respose_data)
    compressed = read(iob, UInt8)
    datalen = ntoh(read(iob, UInt32))
    readproto(iob, response)
    return response
end

"""
function call_method(
    channel::gRPCChannel,
    service::ServiceDescriptor,
    method::MethodDescriptor,
    controller::gRPCController,
    request)
    #write_request(channel, controller, service, method, request)
    response_type = get_response_type(method)
    response = response_type()
    #read_response(channel, controller, response)
end
"""



function process(proto_service::ProtoService)
    println("process $(proto_service)")
end

"""
    Generate Julia gRPC files.
"""
function generate_julia_grpc(proto_dir::String, jl_out_dir::String)
    if !isdir(jl_out_dir)
        println("Generating Julia proto file ...")
        mkdir(jl_out_dir)

        ProtoBuf.protoc(`-I=$(proto_dir) --julia_out=$(jl_out_dir) route_guide.proto`)
    end
end

"""
    Install pip3 modules.
"""
function python_install_requirements()
    pip_os = pyimport("pip")
    pip_os.main(["list"])
    pip_os.main(["install", "grpcio"])
    pip_os.main(["install", "grpcio-tools"])
end

"""
    Generate Python gRPC files.
"""
function generate_python_grpc(proto_dir::String, py_out_dir::String)
    #if !isdir(py_out_dir)

        println("Generating Python proto file from folder: $(pwd())...")
        #mkdir(py_out_dir)

        py_command = pyimport("grpc.tools.command")

        # Add '-V' as a first argument.
        py_command.protoc.main(`-V --proto_path=./test --python_out=$(py_out_dir) --grpc_python_out=$(py_out_dir) proto/route_guide.proto`)
    #end
end

"""
    Calling into python.
"""
function call_python()
    println("call_python")

    # Calling from gRPC.jl/test.
    py"""
    def hello_from_module(name: str) -> str:
        import python_test.mymodule.mymodule as mm

        #import python_test.mymodule.server as server
        #server.serve()

        import python_test.mymodule.client as cl
        cl.run()

        # mm.hello_world(name)
        return "abc"
    """

    x = py"hello_from_module"("Julia")
    @show x

    py"""
    import numpy as np

    def sinpi(x):
        return np.sin(np.pi * x)
    """

    py"sinpi"(1)
end



# Verifies calling into Nghttp library.
@testset "gRPC " begin

    proto_dir = "$(pwd())/test/proto"
    jl_out_dir = "$(pwd())/test/proto/proto_jl_out"
    py_out_dir = "$(pwd())/test/python_test/mymodule"
    @show jl_out_dir

    # Example how to use PyCall
    py_sys = pyimport("sys")
    @show py_sys.version
    py_os = pyimport("os")
    @show py_os.__file__

    # Install gRPC modules
    #python_install_requirements()

    # Julia codegen
    #generate_julia_grpc(proto_dir, jl_out_dir)

    # Python codegen
    #generate_python_grpc(proto_dir, py_out_dir)

    # Configure python path for the local imports.
    println(@__DIR__)
    # Both are required for proper imports
    #pushfirst!(PyVector(pyimport("sys")."path"), @__DIR__)
    #pushfirst!(PyVector(pyimport("sys")."path"), "$(@__DIR__)/python_test/mymodule")
    #call_python()


    # Client
    #include("$(jl_out_dir)/routeguide.jl")
    #route_guide_proto_service = routeguide.RouteGuide(RouteGuideTestHander)
    #process(route_guide_proto_service)

    grpc_channel = gRPCChannel()

    routeGuide = routeguide.RouteGuideBlockingStub(grpc_channel)
    controller = gRPCController()

    in_point = routeguide.Point()
    in_point.latitude = 44
    in_point.longitude = 46

    result = routeguide.GetFeature(routeGuide, controller, in_point)
    @show result

    println("Hello after")

    @test true
end


