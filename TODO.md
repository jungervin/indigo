## TO DO

### General

1. Add autoconfig or cmake build

### Documents

1. introduction
2. users guide for indigo_server and command line client
3. developers guide for drivers
4. developers guide for client apps

### Framework

1. Snooping support
2. Client API for easier integration to client apps & GUI __DONE__
3. ASCOM client adapter __PARTIALLY_DONE__
4. Multipoint alignment engine for mount drivers
5. integrated http server for binary blob download __DONE__
6. HTTP/JSON protocol adapters __DONE__
7. Windows port
8. Android port
9. JPEG format support __DONE__
10. smart serial port selection __DONE__

### Utilities

#### indigo_server

1. posibility to run external drivers dynamic libraries in indigo_server (INDI style drivers) __DONE__
2. posibility to run external drivers executables in indigo_server (INDI style drivers) __DONE__
3. posibility to add driver to indigo_server over INDIGO protocol __DONE__
4. server chaining __DONE__

#### command line client

1. set_property __DONE__
2. get_property (including BLOBs) __DONE__

### Drivers

#### CCDs

1. QHY CCD driver __DONE__
2. ASI CCD driver __DONE__
3. IIDC CCD driver (based on libdc1394) __DONE__
4. MI CCD driver (based on MI SDK)
5. QSI CCD driver (based on QSI SDK)
6. FLI CCD driver (based on FLI SDK) __DONE__
7. SBIG CCD driver (based on SBIG SDK) __DONE__
8. Apogee CCD driver (based on Apogee SDK)
9. Fishcamp CCD driver (based on Fishcamp SDK)
10. Andor CCD driver (based on Andor SDK - payed :( we will require but not provide it)
12. DSI driver. __DONE__
13. ATIK CCD driver __DONE__

#### DSLRs

1. Linux DSLR driver (based on gPhoto)
2. Mac DSLR driver (based on ICA)
3. Canon driver (based on Canon SDK)
4. Nikon driver (based on Nikon SDK)
5. Sony driver (based on WS API)

#### Wheels

1. Atik EFW wheel driver __DONE__
2. FLI wheel driver (based on FLI SDK) __DONE__
3. SBIG wheel driver __DONE__
4. ASI EFW Driver __DONE__

#### Guiders

1. CGUSBST4 guider driver
2. GPUSB guider driver
3. ZWO USB-ST4 __DONE__

#### Focusers

1. USB Focus v3 __DONE__
2. FLI focuser driver (based on FLI SDK) __DONE__
3. SBIG focuser driver (based on SBIG SDK)

#### Mounts

1. NexStar protocol mount driver (based on libnexstar) __DONE__
2. NexStar EVO protocol mount driver
3. LX200 protocol mount driver __DONE__
4. EQMod mount driver
5. ASCOL protocol mount driver (1 & 2m zeiss telescopes upgraded by ProjectSoft)

#### AO

1. SX AO driver
2. SBIG AO driver (based on SBIG SDK)
