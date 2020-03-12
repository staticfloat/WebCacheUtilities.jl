# WebCache Utilities

This package is used to perform a variety of tasks around the Julia web cache/serving infrastructure.  It can be used to determine IP addresses that belong to various CI providers or cloud hosting providers, and can also be used to analyze log files.

## `bin/download_stats.jl`

This script generates reports on download statistics from the official JuliaLang download location.  It can measure trends in downloads, how many of each version of Julia is being downloaded, where these downloads are coming from (cloud vs. non-cloud, separating out CI etc...).  Note that Azure cloud traffic is completely excluded right now, as we are unable to separate out GitHub actions activity from other Azure activity (this will be fixed in the future).

## Credentials

Some of the functionality in this package relies upon having access credentials, saved as environment variables:

* To download graylog logfiles, you'll need to set `GRAYLOG_USERNAME` and `GRAYLOG_PASSWORD`.

* To manipulate Fastly ACLs, you'll need to set `FASTLY_API_TOKEN`.