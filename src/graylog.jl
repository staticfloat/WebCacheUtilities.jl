using HTTP, Dates, JSON

export get_graylog_csv, parse_message

function download_process(filename, time_period, lifetime; kwargs...)
    raw_filename = string(filename, ".raw")
    raw_path = hit_file_cache(raw_filename, lifetime) do raw_path
        download_graylog_csv(raw_path; time_period=time_period, kwargs...)
    end
    return hit_file_cache(filename, lifetime) do csv_path
        parse_graylog_csv(raw_path, csv_path)
    end
end

# If csv_path is not given; default to using the file cache
function get_graylog_csv(time_period::TimePeriod = Hour(48); kwargs...)
    filename = "graylog_$(Second(time_period).value).csv"
    download_process(filename, time_period, Hour(24); kwargs...)
end
function get_graylog_csv(time_period::Tuple{DateTime,DateTime}; kwargs...)
    filename = "graylog_from$(string(time_period[1]))_to$(string(time_period[2])).csv"
    download_process(filename, time_period, Hour(24*365); kwargs...)
end

graylog_session_token = Ref("")
function get_graylog_token(username=nothing, password=nothing; server="graylog.ip.cflo.at")
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
                              server = "graylog.ip.cflo.at")
    params = (
        "query" => "*",
        "fields" => "message",
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

    # Once we've downloaded the .csv, we're going to parse it into a new CSV:
    return csv_path
end

function parse_graylog_csv(in_csv::String, out_csv::String)
    new_df = DataFrame(parse_message.(eachrow(CSV.read(in_csv))))
    CSV.write(out_csv, new_df)
end

function parse_message(row)
    # Attempt to parse out the stuff we're interested in:
    m = match(r"""^
            (?<cache_name>[^ ]+)\s+
            (?<log_server>[^ ]+):\s+
            (?<http_src>[a-f:\d\.]+)\s+
            (?<hostname>[^ ]+)\s+
            ".*"\s+".*"\s+
            \[(?<timestamp>.*)\]\s+
            "(?<http_method>[^ ]+)\s+(?<http_uri>.*)\s+[^ ]+"\s+
            (?<http_response_code>\d+)\s+
            (?<http_payload_size>\d+|(:?"-"))\s*
            ("?(?<http_user_agent>.*)"?)?\s*
        $"""x, row[:message])

    field_names = (:cache_name, :log_server, :http_src, :hostname, :http_method, :http_uri, :http_response_code, :http_payload_size, :http_user_agent)
    new_row = Dict{Symbol,Any}(f => missing for f in field_names)
    new_row[:timestamp] = get(row, :timestamp, nothing)
    if m !== nothing
        for field_name in field_names
            if m[field_name] !== nothing && m[field_name] != "\"-\""
                val = strip(m[field_name])
                if field_name in (:http_response_code, :http_payload_size)
                    val = parse(Int, val)
                end
                new_row[field_name] = val
            end
        end
    end
    return new_row
end
