using PyCall

function config_py_path()
    println(@__DIR__)
    # Both are required for proper imports
    pushfirst!(PyVector(pyimport("sys")."path"), @__DIR__)
    return pushfirst!(PyVector(pyimport("sys")."path"), "$(@__DIR__)/python_test/mymodule")
end

pybytes(bytes) = PyObject(
    ccall(
        PyCall.@pysym(PyCall.PyString_FromStringAndSize),
        PyPtr,
        (Ptr{UInt8}, Int),
        bytes,
        sizeof(bytes)))

"""
    Calling into python.
"""
function python_client()
    try
        println("[[$(Threads.threadid())]] python_client")

        # Calling from gRPC.jl/test.
        py"""
        def hello_from_module(name: str) -> str:
            try:
                import sys
                import traceback
                import python_test.mymodule.client as cl

                cl.run()
            except:
                e = sys.exc_info()[0]
                return str(traceback.format_exc())

            return "=>OK"
        """
    catch e
        @error "[process_queue] failed:" exception = (e, catch_backtrace())
    end

    x = py"hello_from_module"("Julia")
    @show x
    return x
end

function python_server(private_key_pem, public_key_pem)
    # Create python objects.
    private_key_py = pybytes(private_key_pem)
    public_key_py = pybytes(public_key_pem)

    # Calling from gRPC.jl/test.
    py"""
    def hello_from_module(name: str, private_key_py, public_key_py):
        import python_test.mymodule.server as server
        return server.serve(private_key_py, public_key_py)
    """

    x = py"hello_from_module"("Julia", private_key_py, public_key_py)
    @show x
    return x
end

config_py_path()
