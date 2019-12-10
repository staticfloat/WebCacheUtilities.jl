module Travis
import ..IPSubnet, ..dig_cache

function prefixes()
    # Hit `nat.travisci.net` for a list of IP addresses, return them as fully-specified subnets
    return [IPSubnet(ip, 32) for ip in dig_cache("nat.travisci.net", "A")]
end

end # module Travis