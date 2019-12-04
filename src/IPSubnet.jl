export IPSubnet, @subnet_str

import Base: show, in

# We should have something like this within Sockets maybe?
"""
    IPSubnet

Represents an IPv4 or IPv6 subnet, typically represneted through CIDR notation via a base
address and a mask, e.g. `"10.10.11.7/31"`.  Trivially constructable through the
`@subnet_str` string macro, e.g. `subnet"10.10.11.7/31"`.

Easily test whether an `IPAddr` is located within an `IPSubnet` via the `in` keyword.
"""
struct IPSubnet{I <: IPAddr, E <: Union{UInt32,UInt128}}
    address::I
    mask::UInt8
    expanded_mask::Union{UInt32,UInt128}

    function IPSubnet(address::I, mask::Integer) where {I <: IPAddr}
        if mask < 0
            throw(DomainError("mask must be nonnegative"))
        end

        if I <: IPv4 && mask > 32
            throw(DomainError("IPv4 subnets cannot contain mask values larger than 32"))
        end
        
        if I <: IPv6 && mask > 128
            throw(DomainError("IPv4 subnets cannot contain mask values larger than 128"))
        end

        # Helper functions to turn `/8` into `0xff000000`, etc...
        function expand_mask(::IPv4, num_ones)
            return unsafe_trunc(UInt32, unsafe_trunc(UInt32, -1) - ((UInt32(0x1) << (32 - num_ones)) - 1))
        end
        function expand_mask(::IPv6, num_ones)
            return unsafe_trunc(UInt128, unsafe_trunc(UInt128, -1) - ((UInt128(0x1) << (128 - num_ones)) - 1))
        end

        # Canonicalize address representation (e.g. 1.1.1.1/31 is functionally equivalent to 1.1.1.0/31)
        expanded_mask = expand_mask(address, mask)
        address = I(address.host & expanded_mask)

        # Actually construct it
        expanded_mask_type(::Type{IPv4}) = UInt32
        expanded_mask_type(::Type{IPv6}) = UInt128
        return new{I,expanded_mask_type(I)}(address, UInt8(mask), expanded_mask)
    end
end

# Support building an IPSubnet out of strings and whatnot
IPSubnet(address::AbstractString, mask::Integer) = IPSubnet(parse(IPAddr, address), mask)
function IPSubnet(address_and_mask::AbstractString)
    am_split = split(address_and_mask, "/")
    if length(am_split) != 2
        error("IPSubnet(str) must provide a string of the form: \"<ip_address>/<mask>\"")
    end
    return IPSubnet(parse(IPAddr, am_split[1]), parse(Int, am_split[2]))
end

# Make subnet construction as easy as pie
macro subnet_str(address_and_mask)
    IPSubnet(address_and_mask)
end

function show(io::IO, x::IPSubnet)
    print(io, "subnet\"$(x.address)/$(x.mask)\"")
end

# Define set operations for `IPAddr`s and `IPSubnet`s
function in(addr::I, subnet::IPSubnet{I}) where {I <: IPAddr}
    return (addr.host & subnet.expanded_mask) == subnet.address.host
end

# Fast-path nonmatching address-to-subnet operations as `false`
in(addr::IPv4, subnet::IPSubnet{<:IPv6}) = false
in(addr::IPv6, subnet::IPSubnet{<:IPv4}) = false