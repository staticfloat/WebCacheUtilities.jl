
push!(LOAD_PATH, abspath(joinpath(@__DIR__, "..")))

using WebCacheUtilities
using WebCacheUtilities.Fastly

# We hardcode our VCL snippet mappings here, since we don't
# actually have caching servers deployed in all of them
cached_providers = [
    ("packet", "ewr1-cache.ip.cflo.at"),
    ("gce", "storage.googleapis.com"),
]

for aws_zone in ("us-east-1",)
    push!(cached_providers, ("aws-$(aws_zone)", "s3.amazonaws.com"))
end

for azure_zone in ("westus", "westus2", "eastus", "eastus2", "centralus", "northcentralus", "southcentralus")
    push!(cached_providers, ("azure-$(azure_zone)", "julialang2$(azure_zone).blob.core.windows.net"))
end

@info("Deploying $(length(cached_providers) + 1) redirect rules per service")

for (service_name, service_id, http_prefix) in (("julialang-s3", "5hWv4ilX4OJgzwCiZYpqtI", "/julialang2"),
                                                ("julialangnightlies-s3", "1zKTkKmU8dXHBMzCG9uSyK", "/julialangnightlies"))
    service_version = get_mutable_service_version(service_id)
    for (provider_name, provider_host) in cached_providers
        acl_name = replace(lowercase(provider_name), "-" => "_")
        @info("Updating VCL snippet for $(acl_name) on $(service_name)")

        set_redirect_snippet(service_id, service_version, acl_name, provider_host, http_prefix)
    end
    set_base_redirect_snippet(service_id, service_version)
end
