
push!(LOAD_PATH, abspath(joinpath(@__DIR__, "..")))

using WebCacheUtilities
using WebCacheUtilities.Fastly

# We hardcode our VCL snippet mappings here, since we don't
# actually have caching servers deployed in all of them
cached_providers = [
    ("packet", "ewr1-cache.e.ip.saba.us", "/julialang2"),
    ("gce", "storage.googleapis.com", "/julialang2"),
]

for aws_zone in ("us-east-1",)
    # We don't have separate AWS buckets........ YET.
    push!(cached_providers, ("aws-$(aws_zone)", "julialang2.s3.amazonaws.com", ""))
end

for azure_zone in ("westus", "westus2", "eastus", "eastus2", "centralus", "northcentralus", "southcentralus")
    push!(cached_providers, ("azure-$(azure_zone)", "julialang2$(azure_zone).blob.core.windows.net", "/julialang2"))
end

@info("Deploying $(length(cached_providers) + 1) redirect rules per service")

for (service_name, service_id) in ("julialang-s3" => "5hWv4ilX4OJgzwCiZYpqtI",
                                   "julialangnightlies-s3" => "1zKTkKmU8dXHBMzCG9uSyK")
    service_version = get_mutable_service_version(service_id)
    for (provider_name, provider_host, provider_http_prefix) in cached_providers
        acl_name = replace(lowercase(provider_name), "-" => "_")
        @info("Updating VCL snippet for $(acl_name) on $(service_name)")

        set_redirect_snippet(service_id, service_version, acl_name, provider_host, provider_http_prefix)
    end
    set_base_redirect_snippet(service_id, service_version)
end