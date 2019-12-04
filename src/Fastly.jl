module Fastly
using HTTP, JSON
import ..IPSubnet

export get_mutable_service_version, create_acl, delete_acl, update_acl

function add_fastly_token!(headers::Dict)
    # TODO: Do something slightly smarter here
    headers["Fastly-Key"] = get(ENV, "FASTLY_API_TOKEN", "")
end

"""
    fastly(method, service_id, endpoint)

Perform an HTTP request against the given Fastly service on a particular endpoint.
Returns the HTTP response object, get at the body via something like:

    r = fastly("GET", service_id, "version")
    body = JSON.parse(String(r.body))
"""
function fastly(method, service_id, endpoint; headers=Dict{String,String}(), data="")
    add_fastly_token!(headers)
    return HTTP.request(method,
        "https://api.fastly.com/service/$(service_id)/$(endpoint)",
        headers,
        data;
        status_exception = false,
    )
end

"""
    clone_service_version(service_id, version_number)

Clone a particular version of a service, return the new version number.
"""
function clone_service_version(service_id, version_number)
    r = fastly("PUT", service_id, "version/$(version_number)/clone")
    if r.status != 200
        error("Could not clone service $(service_id) version $(version_number)")
    end
    return JSON.parse(String(r.body))["number"]
end

"""
    get_mutable_service_version(service_id)

Get the latest mutable version for a particular service.  If the current
version is locked, then clone it and return _that_ version number.
"""
function get_mutable_service_version(service_id)
    version_r = fastly("GET", service_id, "version")
    if version_r.status != 200
        error("Cannot get version of $(service_id)")
    end
    versions = JSON.parse(String(version_r.body))

    # Find the latest version
    max_version = sort(versions, by = v -> v["number"])[end]

    # If it's locked, then clone it
    if max_version["locked"]
        return clone_service_version(service_id, max_version["number"])
    end
    return max_version["number"]
end

"""
    get_acl_id(service_id, service_version, acl_name)

Return the ACL id associated with the given ACL name
"""
function get_acl_id(service_id, service_version, acl_name)
    r = fastly("GET", service_id, "version/$(service_version)/acl/$(acl_name)")
    if r.status != 200
        error("Got HTTP $(r.status) after trying to query the $(acl_name) ACL on $(service_id)")
    end
    return JSON.parse(String(r.body))["id"]
end

"""
    create_acl(service_id, service_version, acl_name)

Create an ACL within the version of the service specified.  Returns its id.
"""
function create_acl(service_id, service_version, acl_name)
    r = fastly("POST", service_id, "version/$(service_version)/acl", data="name=$(acl_name)")
    if r.status == 200
        # We created it!  Return the id:
        return JSON.parse(String(r.body))["id"]
    end

    # If we get a 409, that means the ACL already exists, so we look up its id:
    if r.status == 409
        return get_acl_id(service_id, service_version, acl_name)
    end
    error("Got HTTP $(r.status) after trying to create the $(acl_name) ACL on $(service_id)")
end

function delete_acl(service_id, service_version, acl_name)
    return fastly("DELETE", service_id, "version/$(service_version)/acl/$(acl_name)")
end

function read_acl(serivce_id, service_version, acl_name)
    acl_id = get_acl_id(service_id, service_version, acl_name)
    return read_acl(service_id, acl_id)
end

function read_acl(service_id, acl_id)
    # first, we get the current set of this ACL's contents:
    r = fastly("GET", service_id, "acl/$(acl_id)/entries", headers=Dict("Content-Type" => "vnd.api+json"))
    if r.status != 200
        error("Unable to read ACL $(acl_id) for service $(service_id)")
    end
    return JSON.parse(String(r.body))
end

function update_acl(service_id::String, service_version::String, acl_name::String, prefixes::Vector{<:IPSubnet})
    acl_id = get_acl_id(service_id, service_version, acl_name)
    return update_acl(service_id, acl_id, prefixes)
end

function update_acl(service_id::String, acl_id::String, prefixes::Vector{<:IPSubnet})
    # We're gonna clobber this guy good.
    prefixes = deepcopy(prefixes)
    
    # first, we get the current set of this ACL's contents:
    previous_entries = try
        read_acl(service_id, acl_id)
    catch
        Dict[]
    end

    new_entries = Dict[]
    # Start by deleting anything that is in previous_entries but not prefixes:
    for pe in previous_entries
        prefix = IPSubnet(pe["ip"], pe["subnet"])
        if !(prefix in prefixes)
            @info("Deleting $(prefix)")
            push!(new_entries, Dict(
                "op" => "delete",
                "id" => pe["id"],
            ))
        else
            #print("Keeping %s"%(prefix))
            # If the exact same one exists, don't add it a second time
            filter!(p -> p != prefix, prefixes)
        end
    end
        
    # Now add anything that is new
    for prefix in prefixes
        @info("Adding $(prefix)")
        push!(new_entries, Dict(
            "op" => "create",
            "ip" => string(prefix.address),
            "subnet" => prefix.mask,
        ))
    end

    r = fastly(
        "PATCH",
        service_id,
        "acl/$(acl_id)/entries";
        data=JSON.json(Dict("entries" => new_entries)),
        headers=Dict("Content-type" => "application/json"),
    )
    if r.status != 200
        error("Unable to set $(acl_id) on service $(service_id)")
    end
    return r
end


# Testing script
# using WebCacheUtilities
# using WebCacheUtilities.Fastly
# service_id = "5hWv4ilX4OJgzwCiZYpqtI"
# service_version = get_mutable_service_version(service_id)
# acl_id = create_acl(service_id, service_version, "packet")
# update_acl(service_id, acl_id, pxs["Packet"])

end # module Fastly