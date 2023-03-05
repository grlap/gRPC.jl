struct ProtoServiceException <: Exception
    msg::AbstractString
end

abstract type ProtoRpcChannel end
abstract type ProtoRpcController end
abstract type AbstractProtoServiceStub{B} end

#
# MethodDescriptor begin
const MethodDescriptor = Tuple{Symbol, Int64, DataType, DataType}

# ==============================

get_request_type(meth::MethodDescriptor) = meth[3]
get_response_type(meth::MethodDescriptor) = meth[4]

# ==============================
# MethodDescriptor end
#

#
# ServiceDescriptor begin
# ==============================
struct ServiceDescriptor
    name::AbstractString
    index::Int
    methods::Dict{String, MethodDescriptor}

    ServiceDescriptor(name::AbstractString, index::Int, methods::Dict{String, MethodDescriptor}) = new(name, index, methods)
end

function find_method(svc::ServiceDescriptor, name::AbstractString)
    (name in keys(svc.methods)) || throw(ProtoServiceException("Service $(svc.name) has no method named $(name)"))
    svc.methods[name]
end

# ==============================
# ServiceDescriptor end
#

#
# Service begin
# ==============================
struct ProtoService
    desc::ServiceDescriptor
    impl_module::Module
end

get_request_type(svc::ProtoService, meth::MethodDescriptor) = get_request_type(find_method(svc, meth))
get_response_type(svc::ProtoService, meth::MethodDescriptor) = get_response_type(find_method(svc, meth))
get_descriptor_for_type(svc::ProtoService) = svc.desc


# ==============================
# Service end
#

#
# Service Stubs begin
# ==============================
struct GenericProtoServiceStub{B} <: AbstractProtoServiceStub{B}
    desc::ServiceDescriptor
    channel::ProtoRpcChannel
    blocking::Bool

    # This inner constructor syntax works with both Julia .5 and .6
    function GenericProtoServiceStub{B}(desc::ServiceDescriptor, channel::ProtoRpcChannel) where B
        new{B}(desc, channel, B)
    end
end

const ProtoServiceBlockingStub = GenericProtoServiceStub{true}

# ==============================
# Service Stubs end
#
