module helloworld
const _ProtoBuf_Top_ = @static if isdefined(parentmodule(@__MODULE__), :_ProtoBuf_Top_)
    (parentmodule(@__MODULE__))._ProtoBuf_Top_
else
    parentmodule(@__MODULE__)
end
include("helloworld_pb.jl")
end
