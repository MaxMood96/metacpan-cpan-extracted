SLµRM UDP Transport
===================

While SLµRM is primarily intended as a data transport across byte-based serial links such as twisted-pair cable and the like, there may be times when it is useful to use IP-based communication to transport messages; either directly to endpoints or to implement ethernet-to-RS485 bridge devices and so on. This document provides a way to achieve this.

This transport mechanism is independent of the port number used, but suggests 11485 as a memorable port likely to be available to use.

Packet Format
-------------

UDP packets correspond one-to-one with individual MSLµRM packets, prefixed with a header consisting of an 8-byte ASCII magic field for indentification, two single-byte version numbers, and a 16bit opcode field.

    char[8]   magic          "udpSLuRM"
    int8      version_major  0
    int8      version_minor  0
    int16     opcode

The magic text field is sent in text order (i.e. the 'u' is the first byte in the packet), and the 16bit opcode field is sent in big-endian order. The version fields should both be zero; later versions would be indicated by higher numbers. Implementations should ignore any received packets that don't match the magic or version numbers.

The opcode field indicates what the remaining body of the packet contains. Currently there is only one valid opcode; 0x0001. This indicates that the remaining body contains a single MSLµRM packet *without* its leading SYNC byte (0x55). The packet is otherwise stored in its complete wire form, including both the header and the whole-packet CRC8 protection checksums.
