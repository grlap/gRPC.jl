module routeguide

include("route_guide_pb.jl")

using gRPC

# service methods for RouteGuide
const _RouteGuide_methods = gRPC.MethodDescriptor[
    gRPC.MethodDescriptor("GetFeature", 1, Point, Feature),
    gRPC.MethodDescriptor("ListFeatures", 2, Rectangle, AbstractChannel{Feature}),
    gRPC.MethodDescriptor("RecordRoute", 3, AbstractChannel{Point}, RouteSummary),
    gRPC.MethodDescriptor("RouteEcho", 4, RouteNote, RouteNote),
    gRPC.MethodDescriptor("RouteChat", 5, AbstractChannel{RouteNote}, AbstractChannel{RouteNote}),
    gRPC.MethodDescriptor("TerminateServer", 6, Empty, Empty),
] # const _RouteGuide_methods
const _RouteGuide_desc = gRPC.ServiceDescriptor("routeguide.RouteGuide", 1, _RouteGuide_methods)

RouteGuide(impl::Module) = gRPC.ProtoService(_RouteGuide_desc, impl)

mutable struct RouteGuideStub <: gRPC.AbstractProtoServiceStub{false}
    impl::gRPC.ProtoServiceStub
    RouteGuideStub(channel::gRPC.ProtoRpcChannel) = new(gRPC.ProtoServiceStub(_RouteGuide_desc, channel))
end # mutable struct RouteGuideStub

mutable struct RouteGuideBlockingStub <: gRPC.AbstractProtoServiceStub{true}
    impl::gRPC.ProtoServiceBlockingStub
    RouteGuideBlockingStub(channel::gRPC.ProtoRpcChannel) = new(gRPC.ProtoServiceBlockingStub(_RouteGuide_desc, channel))
end # mutable struct RouteGuideBlockingStub

GetFeature(stub::RouteGuideStub, controller::gRPC.ProtoRpcController, inp, done::Function) =
    call_method(stub.impl, _RouteGuide_methods[1], controller, inp, done)
GetFeature(stub::RouteGuideBlockingStub, controller::gRPC.ProtoRpcController, inp) =
    call_method(stub.impl, _RouteGuide_methods[1], controller, inp)

ListFeatures(stub::RouteGuideStub, controller::gRPC.ProtoRpcController, inp, done::Function) =
    call_method(stub.impl, _RouteGuide_methods[2], controller, inp, done)
ListFeatures(stub::RouteGuideBlockingStub, controller::gRPC.ProtoRpcController, inp) =
    call_method(stub.impl, _RouteGuide_methods[2], controller, inp)

RecordRoute(stub::RouteGuideStub, controller::gRPC.ProtoRpcController, inp, done::Function) =
    call_method(stub.impl, _RouteGuide_methods[3], controller, inp, done)
RecordRoute(stub::RouteGuideBlockingStub, controller::gRPC.ProtoRpcController, inp) =
    call_method(stub.impl, _RouteGuide_methods[3], controller, inp)

RouteEcho(stub::RouteGuideStub, controller::gRPC.ProtoRpcController, inp, done::Function) =
    call_method(stub.impl, _RouteGuide_methods[4], controller, inp, done)
RouteEcho(stub::RouteGuideBlockingStub, controller::gRPC.ProtoRpcController, inp) =
    call_method(stub.impl, _RouteGuide_methods[4], controller, inp)

RouteChat(stub::RouteGuideStub, controller::gRPC.ProtoRpcController, inp, done::Function) =
    call_method(stub.impl, _RouteGuide_methods[5], controller, inp, done)
RouteChat(stub::RouteGuideBlockingStub, controller::gRPC.ProtoRpcController, inp) =
    call_method(stub.impl, _RouteGuide_methods[5], controller, inp)

TerminateServer(stub::RouteGuideStub, controller::gRPC.ProtoRpcController, inp, done::Function) =
    call_method(stub.impl, _RouteGuide_methods[6], controller, inp, done)
TerminateServer(stub::RouteGuideBlockingStub, controller::gRPC.ProtoRpcController, inp) =
    call_method(stub.impl, _RouteGuide_methods[6], controller, inp)

export Empty, Point, Rectangle, Feature, RouteNote, RouteSummary, RouteGuide, RouteGuideStub, RouteGuideBlockingStub,
    GetFeature, ListFeatures, RecordRoute, RouteEcho, RouteChat, TerminateServer

end # module routeguide
