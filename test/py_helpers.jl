using PyCall

function config_py_path()
    println(@__DIR__)
    # Both are required for proper imports
    pushfirst!(PyVector(pyimport("sys")."path"), @__DIR__)
    return pushfirst!(PyVector(pyimport("sys")."path"), "$(@__DIR__)/python_test/mymodule")
end

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

function python_server()
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

config_py_path()
