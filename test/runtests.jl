"""

    arm64
    ~/miniforge3/bin/python3

    https://betterprogramming.pub/using-python-and-r-with-julia-b7019a3d1420


Final list:
[ ] Http2Stream can read buffer with given length


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

    io = to_delimited_message_bytes(request)

    stream_id1 = submit_request(
        channel.session,
        io,
        headers)

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


function read_request(http2_server_session::Http2ServerSession, controller::gRPCController, proto_service::ProtoService)
    request_stream = recv(http2_server_session)
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
    @show method

    request_type = get_request_type(proto_service, method)
    request_argument = request_type()

    request_data = read_all(request_stream)

    iob = IOBuffer(request_data)
    compressed = read(iob, UInt8)
    datalen = ntoh(read(iob, UInt32))
    readproto(iob, request_argument)

    response = call_method(proto_service, method, controller, request_argument)
    println("Prepare for response")

    io = to_delimited_message_bytes(response)

    println("-> submit_response")
    submit_response(
        request_stream,
        io,
        gRPC.DEFAULT_STATUS_200,
        gRPC.DEFAULT_TRAILER)

#    if evt.is_end_stream
#        data = UInt8[]
#    else
#        data_evt = Session.take_evt!(connection)
#        data = data_evt.data
#    end

#    @debug("received request", method, path, stream_id=channel.stream_id, servicename,
#           methodname, nbytes=length(data))

#    service = services[servicename]
#    method = find_method(service, methodname)
#    request_type = get_request_type(service, method)
#    request = request_type()
#    from_delimited_message_bytes(data, request)

#    service, method, request
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

    controller = gRPCController()
"""
    tcp_connection = connect("localhost", 50051)
    grpc_channel = gRPCChannel(Nghttp2.open(tcp_connection))

    routeGuide = routeguide.RouteGuideBlockingStub(grpc_channel)

    in_point = routeguide.Point()
    in_point.latitude = 44
    in_point.longitude = 46

    for n in 1:10
        result = routeguide.GetFeature(routeGuide, controller, in_point)
    end

"""
    route_guide_proto_service::ProtoService = RouteGuideTestHander.routeguide.RouteGuide(RouteGuideTestHander)

    socket = listen(5000)
    accepted_socket = accept(socket)

    nghttp2_server_session = Nghttp2.from_accepted(accepted_socket)

    #service, method, request = 
    read_request(nghttp2_server_session, controller, route_guide_proto_service)

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


