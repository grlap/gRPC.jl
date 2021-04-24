#
using ProtoBuf

proto_dir = "$(pwd())/test/proto"
jl_out_dir = "$(pwd())/test/proto/proto_jl_out"
py_out_dir = "$(pwd())/test/python_test/mymodule"


"""
    Generate Julia gRPC files.
"""
function generate_julia_grpc(proto_dir::String, jl_out_dir::String)
    if !isdir(jl_out_dir)
        println("Generating Julia proto file ...")
        mkdir(jl_out_dir)
    end

    ProtoBuf.protoc(`-I=$(proto_dir) --julia_out=$(jl_out_dir) route_guide.proto`)
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

    # Install gRPC modules
    #python_install_requirements()

    # Julia codegen
    #generate_julia_grpc(proto_dir, jl_out_dir)

    # Python codegen
    #generate_python_grpc(proto_dir, py_out_dir)
