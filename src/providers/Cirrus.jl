module Cirrus
import ..IPSubnet, ..dig_cache

function prefixes()
    # So far, Cirrus provides only two NAT hostnames to hit; `macstadium` and `gcp`:
    # https://cirrus-ci.org/faq/#ip-addresses-of-community-clusters
    return [
        [IPSubnet(ip, 32) for ip in dig_cache("macstadium.community.nat.cirrus-ci.com")];
        [IPSubnet(ip, 32) for ip in dig_cache("gcp.community.nat.cirrus-ci.com")]
    ]
end

end # module Cirrus