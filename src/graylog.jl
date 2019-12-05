using HTTP, Dates, JSON

export download_graylog_csv

# If csv_path is not given; default to using the file cache
download_graylog_csv(;kwargs...) = hit_file_cache(csv_path -> download_graylog_csv(csv_path; kwargs...), "graylog.csv")

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

function download_graylog_csv(csv_path::AbstractString;
                              auth = get_graylog_token(),
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