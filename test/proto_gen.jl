"""
    Generate proto files.

[x] Proto python
[x] Proto Julia 

"""

using ProtoBuf
using PyCall

"""
    Gets proto files include folder.
"""
function get_proto_include_dir()
    py"""
    def get_python_path() -> str:
        import os
        import inspect

        return inspect.getfile(os)
    """

    python_os_path = py"get_python_path()"

    python_os_directory, _ = splitdir(python_os_path)

    protobuf_include = joinpath(python_os_directory, "site-packages", "grpc_tools", "_proto")
    return protobuf_include
end

"""
    Generates Julia gRPC files.
"""
function generate_julia_grpc(proto_dir::String, jl_out_dir::String)
    if !isdir(jl_out_dir)
        println("Generating Julia proto file ...")
        mkdir(jl_out_dir)
    end

    proto_include_dir = "$(get_proto_include_dir())"

    args = `-I=$(proto_include_dir) --proto_path=$(proto_dir) --julia_out=$(jl_out_dir) route_guide.proto helloworld.proto`
    ProtoBuf.protoc(args)

    return nothing
end

"""
    Generates Python gRPC files.

    Equivalent of running the command:
    python -m grpc_tools.protoc -I../../protos --python_out=. --grpc_python_out=. ../../protos/route_guide.proto
"""
function generate_python_grpc(proto_dir::String, py_out_dir::String)
    #if !isdir(py_out_dir)

    println("Generating Python proto file from folder: $(pwd())...")
    #mkdir(py_out_dir)

    py_command = pyimport("grpc.tools.command")

    proto_include_dir = "$(get_proto_include_dir())"

    args = `--proto_path=$(proto_include_dir) --proto_path=./test --python_out=$(py_out_dir) --grpc_python_out=$(py_out_dir) proto/route_guide.proto proto/helloworld.proto`
    py_command.protoc.main(args)

    return nothing
end

proto_dir = "$(pwd())/test/proto"
jl_out_dir = "$(pwd())/test/proto/proto_jl_out"
py_out_dir = "$(pwd())/test/python_test/mymodule"

# Julia codegen
generate_julia_grpc(proto_dir, jl_out_dir)

# Python codegen
generate_python_grpc(proto_dir, py_out_dir)
