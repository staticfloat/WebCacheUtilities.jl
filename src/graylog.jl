using HTTP, Dates

export download_graylog_csv

# If csv_path is not given; default to using the file cache
download_graylog_csv(;kwargs...) = hit_file_cache(csv_path -> download_graylog_csv(csv_path; kwargs...), "graylog.csv")

function download_graylog_csv(csv_path::AbstractString;
                              auth = get(ENV, "GRAYLOG_TOKEN", ""),
                              time_period::TimePeriod=Hour(48),
                              fields::Tuple = ("http_payload_size", "http_src", "http_uri",),
                              server = "graylog.e.ip.saba.us",
                              api_endpoint = "api/search/universal/relative/export")
    params = (
        "query" => "*",
        "fields" => join(fields, ","),
        "range" => "$(Second(time_period).value)",
    )
    try
        r = open(csv_path, "w") do io
            HTTP.get(
                "https://$(auth)@$(server)/$(api_endpoint)";
                query=params,
                basic_authorization=true,
                response_stream=io
            )
        end

        if r.status != 200
            error("Unable to get CSV file from $(server)")
        end
    catch e
        rm(csv_path, force=true)
        rethrow(e)
    end
    return csv_path
end