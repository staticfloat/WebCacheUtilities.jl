using HTTP, JSON, Pkg.BinaryPlatforms, WebCacheUtilities, SHA


up_os(p::Windows) = "winnt"
up_os(p::MacOS) = "mac"
up_os(p::Linux) = "linux"
up_os(p::FreeBSD) = "freebsd"
up_os(p) = error("Unknown OS for $(p)")

up_arch(p::Platform) = up_arch(arch(p))
function up_arch(arch::Symbol)
    if arch == :x86_64
        return "x64"
    elseif arch == :i686
        return "x86"
    elseif arch == :powerpc64le
        return "ppc64le"
    else
        return string(arch)
    end
end

tar_os(p::Windows) = "win$(wordsize(p))"
tar_os(p::MacOS) = "mac$(wordsize(p))"
tar_os(p::FreeBSD) = "freebsd-$(arch(p))"
function tar_os(p::Linux)
    if arch(p) == :powerpc64le
        return "linux-ppc64le"
    else
        return "linux-$(arch(p))"
    end
end

jlext(p::Windows) = "exe"
jlext(p::MacOS) = "dmg"
jlext(p::Platform) = "tar.gz"

# Get list of tags from the Julia repo
@info("Probing for tag list...")
tags_json_path = WebCacheUtilities.download_to_cache(
    "julia_tags.json",
    "https://api.github.com/repos/JuliaLang/julia/git/refs/tags",
)
tags = JSON.parse(String(read(tags_json_path)))

function vnum_maybe(x::AbstractString)
    try
        return VersionNumber(x)
    catch
        return nothing
    end
end
function is_stable(v::VersionNumber)
    return v.prerelease == () && v.build == ()
end
tag_versions = filter(x -> x !== nothing, [vnum_maybe(basename(t["ref"])) for t in tags])

function download_url(version::VersionNumber, platform::Platform)
    return string(
        "https://julialang-s3.julialang.org/bin/",
        up_os(platform), "/",
        up_arch(platform), "/",
        version.major, ".", version.minor, "/", 
        "julia-", version, "-", tar_os(platform), ".", jlext(platform),
    )
end

# We're going to collect the combinatorial explosion of version/os-arch possible downloads.
# We don't have a nice, neat list of what is or is not available, and so we're just going to
# try and download each file, and if it exists, yay.  Otherwise, bleh.
julia_platforms = [
    Linux(:x86_64),
    Linux(:i686),
    Linux(:aarch64),
    Linux(:armv7l),
    Linux(:powerpc64le),
    MacOS(:x86_64),
    Windows(:x86_64),
    Windows(:i686),
    FreeBSD(:x86_64),
]
meta = Dict()
out_path = joinpath(@__DIR__, "..", "data", "versions.json")
for version in tag_versions
    for platform in julia_platforms
        url = download_url(version, platform)
        filename = basename(url)

        # Download this URL to a local file
        local filepath
        try
            @info("Downloading $(filename)...")
            filepath = WebCacheUtilities.download_to_cache(filename, url)
        catch e
            if isa(e, InterruptException)
                rethrow(e)
            end
            continue
        end

        tarball_hash_path = hit_file_cache("$(filename).sha256") do tarball_hash_path
            open(filepath, "r") do io
                open(tarball_hash_path, "w") do hash_io
                    write(hash_io, bytes2hex(sha256(io)))
                end
            end
        end
        tarball_hash = String(read(tarball_hash_path))

        # Initialize overall version key, if needed
        if !haskey(meta, version)
            meta[version] = Dict(
                "stable" => is_stable(version),
                "files" => Vector{Dict}(),
            )
        end

        # Test to see if there is an asc signature:
        asc_signature = nothing
        if !isa(platform, MacOS) && !isa(platform, Windows)
            try
                asc_url = string(url, ".asc")
                @info("Downloading $(basename(asc_url))")
                asc_filepath = WebCacheUtilities.download_to_cache(basename(asc_url), asc_url)
                asc_signature = String(read(asc_filepath))
            catch e
                if isa(e, InterruptException)
                    rethrow(e)
                end
            end
        end

        # Build up metadata about this file
        kind = "archive"
        if endswith(filename, ".exe")
            kind = "installer"
        end
        file_dict = Dict(
            "triplet" => triplet(platform),
            "os" => up_os(platform),
            "arch" => string(arch(platform)),
            "version" => string(version),
            "sha256" => tarball_hash,
            "size" => filesize(filepath),
            "kind" => kind,
            "url" => url,
        )
        # Add in `.asc` signature content, if applicable
        if asc_signature !== nothing
            file_dict["asc"] = asc_signature
        end

        # Right now, all we have are archives, but let's be forward-thinking
        # and make this an array of dictionaries that is easy to extensibly match
        push!(meta[version]["files"], file_dict)

        # Write out new versions of our versions.json as we go
        open(out_path, "w") do io
            JSON.print(io, meta, 2)
        end
    end
end

# Just a way to run this automatically at the end because I'm lazy
run(`s4cmd put -f --API-ACL=public-read $(out_path) s3://julialang2/bin/versions.json`)