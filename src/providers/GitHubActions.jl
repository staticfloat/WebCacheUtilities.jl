module GitHubActions
import ..IPSubnet, ..@subnet_str

function prefixes()
    # These are so far just discovered through trial and error.  :/
    return [
        # MacStadium worker
        subnet"199.7.166.17/32",
    ]
end

end # module GitHubActions