# WebCache Utilities

This package is used to perform a variety of tasks around the Julia web cache/serving infrastructure.  It can be used to determine IP addresses that belong to various CI providers or cloud hosting providers, and can also be used to analyze log files.

## Credentials

Some of the functionality in this package relies upon having access credentials, saved as environment variables:

* To download graylog logfiles, you'll need to set `GRAYLOG_USERNAME` and `GRAYLOG_PASSWORD`.

* To manipulate Fastly ACLs, you'll need to set `FASTLY_API_TOKEN`.