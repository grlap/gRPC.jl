using PyCall

function config_py_path()
    println(@__DIR__)
    # Both are required for proper imports
    pushfirst!(PyVector(pyimport("sys")."path"), @__DIR__)
    pushfirst!(PyVector(pyimport("sys")."path"), "$(@__DIR__)/python_test/mymodule")
end

"""
    Calling into python.
"""
function python_client()
    config_py_path()
    println("[[$(Threads.threadid())]] python_client")

    # Calling from gRPC.jl/test.
    py"""
    def hello_from_module(name: str) -> str:
        import python_test.mymodule.client as cl

        cl.run()
        return "abc"
    """

    x = py"hello_from_module"("Julia")
    @show x
    return x
end

function python_server()
    config_py_path()

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
