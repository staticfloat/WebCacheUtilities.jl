module Fastly
using HTTP, JSON
import ..IPSubnet

export get_mutable_service_version
export create_acl, delete_acl, update_acl, get_acl_id
export set_redirect_snippet, set_base_redirect_snippet, get_snippet_id

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
    deleted = 0
    # Start by deleting anything that is in previous_entries but not prefixes:
    for pe in previous_entries
        prefix = IPSubnet(pe["ip"], pe["subnet"])
        if !(prefix in prefixes)
            deleted += 1
            push!(new_entries, Dict(
                "op" => "delete",
                "id" => pe["id"],
            ))
        else
            # If the exact same one exists, don't add it a second time
            deleteat!(prefixes, findfirst(p -> p == prefix, prefixes))
            # Note that using `filter!(p -> p != prefix, prefixes)` segfaults julia...
        end
    end
        
    # Now add anything that is new
    added = length(prefixes)
    for prefix in prefixes
        push!(new_entries, Dict(
            "op" => "create",
            "ip" => string(prefix.address),
            "subnet" => prefix.mask,
        ))
    end

    if added != 0 || deleted != 0
        @info(" -> Adding $(added) and removing $(deleted) prefixes")

        r = fastly(
            "PATCH",
            service_id,
            "acl/$(acl_id)/entries";
            data=JSON.json(Dict("entries" => new_entries)),
            headers=Dict("Content-type" => "application/json"),
        )
        if r.status != 200
            error("Unable to set ACL $(acl_id) on service $(service_id)")
        end
        return r
    else
        return nothing
    end
end

function get_snippet_id(service_id, service_version, snippet_name)
    r = fastly("GET", service_id, "version/$(service_version)/snippet/$(HTTP.URIs.escapepath(snippet_name))")
    if r.status != 200
        error("Got HTTP $(r.status) after trying to query the $(snippet_name) ACL on $(service_id)")
    end
    return JSON.parse(String(r.body))["id"]
end

function create_snippet(service_id, service_version, snippet_name; content="", type="recv")
    data = JSON.json(Dict(
        "name" => snippet_name,
        "type" => type,
        "dynamic" => "0",
        "content" => content,
    ))
    r = fastly("POST", service_id, "version/$(service_version)/snippet", headers=Dict("Content-Type" => "application/json"), data=data)
    if r.status == 200
        # We created it!  Return the id:
        return JSON.parse(String(r.body))["id"]
    end

    # If we get a 409, that means the snippet already exists, so we look up its id:
    if r.status == 409
        return get_snippet_id(service_id, service_version, snippet_name)
    end
    error("Got HTTP $(r.status) after trying to create the $(snippet_name) snippet on $(service_id)")
end

function update_snippet(service_id, service_version, snippet_name, content; type="recv")
    # Create it just in case it doesn't exist
    create_snippet(service_id, service_version, snippet_name; content=content, type=type)

    data = JSON.json(Dict(
        "content" => content,
    ))
    r = fastly("PUT",
        service_id,
        "version/$(service_version)/snippet/$(HTTP.URIs.escapepath(snippet_name))",
        headers=Dict("Content-Type" => "application/json"),
        data=data,
    )
    if r.status != 200
        error("Unable to set snippet $(snippet_id) on service $(service_id)")
    end
    return r
end

function set_redirect_snippet(service_id, service_version, acl_name, http_host, http_prefix)
    vcl_code = """
    if ( client.ip ~ $(acl_name) ) {
        set req.http.host = "$(http_host)"; # new host URL
        set req.http.prefix = "$(http_prefix)";
        error 750 "$(acl_name) internal redirect trigger";
    }
    """
    update_snippet(service_id, service_version, "redirect $(acl_name)", vcl_code)
end

function set_base_redirect_snippet(service_id, service_version)
    vcl_code = """
    if (obj.status == 750) {
        set obj.status = 302;
        set obj.http.Location = "https://" req.http.host req.http.prefix req.url;
        synthetic {""};
        return (deliver);
    }
    """
    update_snippet(service_id, service_version, "base redirector", vcl_code; type="error")
end

end # module Fastly
