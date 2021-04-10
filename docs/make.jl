using Documenter
using gRPC

makedocs(
    sitename = "gRPC",
    format = Documenter.HTML(),
    modules = [gRPC]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
