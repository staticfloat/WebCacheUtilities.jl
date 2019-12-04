using Dates
export hit_file_cache, cache_json

function download_to_cache(filename::String, url::String)
    file_path = hit_file_cache(filename) do file_path
        r = open(io -> HTTP.get(url; response_stream=io), file_path, "w")
        if r.status != 200
            error("Unable to get AWS IP ranges")
        end
    end
    return file_path
end

function hit_file_cache(creator::Function, filename::String, lifetime::TimePeriod = Hour(24))
    cache_dir = joinpath(@__DIR__, "..", "data")
    if !isdir(cache_dir)
        mkpath(cache_dir)
    end

    file_cache_path = joinpath(cache_dir, filename)
    if stat(file_cache_path).mtime < time() - Second(lifetime).value
        creator(file_cache_path)
    end
    return file_cache_path
end