using HTTP, Dates, JSON

export download_graylog_csv

# If csv_path is not given; default to using the file cache
function download_graylog_csv(time_period::TimePeriod = Hour(48); kwargs...)
    filename = "graylog_$(Second(time_period).value).csv"
    return hit_file_cache(filename) do csv_path
        download_graylog_csv(csv_path; time_period=time_period, kwargs...)
    end
end
function download_graylog_csv(time_period::Tuple{DateTime,DateTime}; kwargs...)
    filename = "graylog_from$(string(time_period[1]))_to$(string(time_period[2])).csv"
    return hit_file_cache(filename, Hour(24*365)) do csv_path
        download_graylog_csv(csv_path; time_period=time_period, kwargs...)
    end
end

graylog_session_token = Ref("")
function get_graylog_token(username=nothing, password=nothing; server="graylog.e.ip.saba.us")
    global graylog_session_token
    if isempty(graylog_session_token[])
        username = something(username, get(ENV, "GRAYLOG_USERNAME", nothing))
        password = something(password, get(ENV, "GRAYLOG_PASSWORD", nothing))

        r = HTTP.post(
            "https://$(server)/api/system/sessions",
            Dict(
                "Content-Type" => "application/json",
                "Accept" => "application/json",
                "X-Requested-By" => "cli",
            ),
            JSON.json(Dict(
                "username" => username,
                "password" => password,
                "host" => "",
            ))
        )
        if r.status != 200
            error("Unable to login to graylog server $(server)")
        end
        session_token = JSON.parse(String(r.body))["session_id"]
        graylog_session_token[] = "$(session_token):session"
    end
    return graylog_session_token[]
end

#https://97b9064d-6a45-445d-af18-601cee7d2796:session@graylog.e.ip.saba.us/api/search/universal/absolute/export?query=%2A&from=2020-02-01T00%3A00%3A00.000Z&to=2020-03-01T00%3A00%3A00.000Z&fields=source%2Cmessage

function download_graylog_csv(csv_path::AbstractString;
                              auth = get_graylog_token(),
                              time_period::Union{TimePeriod,Tuple{DateTime,DateTime}}=Hour(48),
                              fields::Tuple = ("http_payload_size", "http_src", "http_uri", "http_method", "http_response_code", "message"),
                              server = "graylog.e.ip.saba.us")
    params = (
        "query" => "*",
        "fields" => join(fields, ","),
    )

    # If we're given a TimePeriod, then we're doing a relative query.
    if isa(time_period, TimePeriod)
        api_endpoint = "api/search/universal/relative/export"
        params = (params..., "range" => "$(Second(time_period).value)")
    else
        api_endpoint = "api/search/universal/absolute/export"
        params = (params..., "from" => "$(time_period[1]).000Z", "to" => "$(time_period[2]).000Z")
    end
    try
        r = open(csv_path, "w") do io
            r = HTTP.get(
                "https://$(auth)@$(server)/$(api_endpoint)";
                query=params,
                basic_authorization=true,
                response_stream=io,
            )
            return r
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