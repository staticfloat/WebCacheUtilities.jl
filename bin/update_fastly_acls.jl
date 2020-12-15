
push!(LOAD_PATH, abspath(joinpath(@__DIR__, "..")))

using WebCacheUtilities
using WebCacheUtilities.Fastly

# Load in all our provider prefixes
pxs = prefixes_by_provider()
@info("Updating $(length(pxs)) ACLs...")

for (service_name, service_id) in ("julialang-s3" => "5hWv4ilX4OJgzwCiZYpqtI",
                                   "julialangnightlies-s3" => "1zKTkKmU8dXHBMzCG9uSyK",
                                   "pkg" => "2sXVRXIRMUgge2aOICJUTs")
    service_version = get_mutable_service_version(service_id)
    for provider_name in keys(pxs)
        acl_name = replace(lowercase(provider_name), "-" => "_")
        @info("Updating ACL $(acl_name) on $(service_name)")

        acl_id = create_acl(service_id, service_version, acl_name)
        update_acl(service_id, acl_id, pxs[provider_name])
    end
end
