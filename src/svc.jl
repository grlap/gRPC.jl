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

const ServiceDescriptor = Tuple{String, Int, Dict{String, MethodDescriptor}}

function find_method(svc::ServiceDescriptor, method_name::AbstractString)
    svc_name = svc[1]
    svc_methods = svc[3]

    (method_name in keys(svc_methods)) || throw(ProtoServiceException("Service $(svc_name) has no method named $(method_name)"))
    svc_methods[method_name]
end

# ==============================
# ServiceDescriptor end
#

#
# Service begin
# ==============================
const ProtoService = Tuple{ServiceDescriptor, Module}

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
