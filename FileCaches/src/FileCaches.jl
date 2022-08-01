module FileCaches

import Dates
import HTTP

using Dates: Second, TimePeriod

export hit_file_cache

function download_to_cache(filename::String, url::String; kwargs...)
    file_path = hit_file_cache(filename; kwargs...) do file_path
        r = open(io -> HTTP.get(url; response_stream=io), file_path, "w")
        if r.status != 200
            error("Unable to download $(url) to $(filename)")
        end
    end
    return file_path
end

function hit_file_cache(
        creator::Function,
        filename::String;
        lifetime::TimePeriod = Hour(24),
        cleanup::Bool = true,
    )
    cache_dir = joinpath(@__DIR__, "..", "data")
    if !isdir(cache_dir)
        mkpath(cache_dir)
    end

    file_cache_path = joinpath(cache_dir, filename)
    if stat(file_cache_path).mtime < time() - Second(lifetime).value
        try
            creator(file_cache_path)
        catch e
            cleanup && rm(file_cache_path; force=true)
            rethrow(e)
        end
    end
    return abspath(file_cache_path)
end

end # module
