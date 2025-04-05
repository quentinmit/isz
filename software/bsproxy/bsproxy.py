import argparse
import logging
import selectors
import socket
import struct

PORT = 2021
MAX_PACKET_SIZE = 8192

IP_PKTINFO_FORMAT = "@I4s4s"
IP_TTL_FORMAT = "=I"

logger = logging.getLogger("bsproxy")

if not hasattr(socket, "IP_RECVTTL"):
    # Added in 3.14: https://github.com/python/cpython/pull/120058
    socket.IP_RECVTTL = 12


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', action='append', required=True)
    parser.add_argument('-o', action='append')
    parser.add_argument('-v', action='store_true')

    args = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.v else logging.INFO)

    input_interfaces = set(args.i)
    output_interfaces = set(args.o or [])

    sel = selectors.DefaultSelector()

    interface_name_by_index = dict(socket.if_nameindex())
    output_interface_indices = set(
        i
        for i, name
        in interface_name_by_index.items()
        if name in output_interfaces
    )

    # for interface in input_interfaces | output_interfaces:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    # sock.setsockopt(
    #   socket.SOL_SOCKET,
    #   socket.SO_BINDTODEVICE,
    #   interface.encode('ascii') + b'\0',
    # )
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_PKTINFO, 1)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_RECVTTL, 1)
    sock.bind(('255.255.255.255', PORT))
    sock.setblocking(False)
    sel.register(sock, selectors.EVENT_READ)

    def recv(sock):
        msg, ancdata, flags, addr = sock.recvmsg(
            MAX_PACKET_SIZE,
            socket.CMSG_SPACE(MAX_PACKET_SIZE),
        )
        ancdata = {(i, j): d for (i, j, d) in ancdata}
        ipi_ifindex, ipi_spec_dst, ipi_addr = struct.unpack(
            IP_PKTINFO_FORMAT,
            ancdata[(socket.IPPROTO_IP, socket.IP_PKTINFO)],
        )
        ip_ttl, = struct.unpack(
            IP_TTL_FORMAT,
            ancdata[(socket.IPPROTO_IP, socket.IP_TTL)]
        )
        logger.debug(
            "Received packet with TTL %d on interface %s (%d) from %s to %s",
            ip_ttl,
            interface_name_by_index[ipi_ifindex],
            ipi_ifindex,
            socket.inet_ntoa(ipi_spec_dst),
            socket.inet_ntoa(ipi_addr),
        )
        if (
            ip_ttl > 1
            and interface_name_by_index[ipi_ifindex] in input_interfaces
        ):
            for i in output_interface_indices:
                cmsg_data_new = struct.pack(
                    IP_PKTINFO_FORMAT,
                    i,
                    ipi_spec_dst,
                    ipi_addr,
                )
                sock.sendmsg(
                    [msg], [
                        (socket.IPPROTO_IP, socket.IP_PKTINFO, cmsg_data_new),
                        (
                            socket.IPPROTO_IP, socket.IP_TTL,
                            struct.pack(IP_TTL_FORMAT, 1)
                        ),
                    ],
                    0,
                    ('255.255.255.255', PORT),
                )

    while True:
        events = sel.select()
        for key, mask in events:
            recv(key.fileobj)


if __name__ == '__main__':
    main()
