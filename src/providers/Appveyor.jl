module Appveyor
import ..IPSubnet, ..@subnet_str

function prefixes()
    # These are all hardcoded at https://www.appveyor.com/docs/build-environment/#ip-addresses
    return [
        subnet"104.197.110.30/32",
        subnet"104.197.145.181/32",
        subnet"67.225.164.53/32",
        subnet"67.225.164.54/32",
        subnet"67.225.164.96/32",
        subnet"67.225.165.66/32",
        subnet"67.225.165.168/32",
        subnet"67.225.165.171/32",
        subnet"67.225.165.175/32",
        subnet"67.225.165.183/32",
        subnet"67.225.165.185/32",
        subnet"67.225.165.193/32",
        subnet"67.225.165.198/32",
        subnet"67.225.165.200/32",
        subnet"34.208.156.238/32",
        subnet"34.209.164.53/32",
        subnet"34.216.199.18/32",
        subnet"52.43.29.82/32",
        subnet"52.89.56.249/32",
        subnet"54.200.227.141/32",
        subnet"13.83.108.89/32",
        subnet"199.38.85.75/32",
        subnet"207.254.41.120/32",
        subnet"138.91.141.243/32",
    ]
end

end # module Appveyor