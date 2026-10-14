# NovaVM — Ruby CLI + native Intel macOS hypervisor prototype

This is a from-scratch learning-project starter. Ruby (`.rb`) provides the CLI and persistent VM configuration; C++ calls Apple's Hypervisor.framework for an empty-VM lifecycle probe.

## Scope honestly
This is NOT yet a Windows 11-capable emulator. It can create VM metadata and a persistent sparse raw disk, check Hypervisor.framework availability, and create/destroy an empty native VM. It does not yet boot an ISO: x86 reset-state boot, guest RAM mapping, UEFI firmware execution, chipset/device models, storage controllers, graphics, networking, and TPM 2.0 are not implemented.

Apple documentation: https://developer.apple.com/documentation/hypervisor

## Requirements
- Intel Mac and compatible macOS
- Xcode Command Line Tools: `xcode-select --install`
- Ruby
- CMake: `brew install cmake`
- `sysctl -n kern.hv_support` should report `1`

## Build native probe
```sh
cd NovaVM
cmake -S engine -B build
cmake --build build
./build/novavm-engine --check
./build/novavm-engine
```

## Ruby CLI
```sh
ruby bin/novavm.rb create Windows11 --ram 8192 --cpu 4 --disk 64G
ruby bin/novavm.rb status Windows11
ruby bin/novavm.rb disk-info Windows11
ruby bin/novavm.rb hypervisor-check
```
VMs are stored in `~/NovaVM/VMs/<name>/`. `--ram` is MiB and is capped at 80% of detected host RAM. Large configured RAM does not create physical RAM or guarantee the host can allocate it.

## Windows 11 roadmap
1. Implement x86-64 guest reset state and guest RAM mapping.
2. Integrate a UEFI firmware such as OVMF, checking license and redistribution terms.
3. Implement chipset, PCI/PCIe, interrupt controllers, timers, serial/debug console.
4. Implement storage controller, virtual disk, and ISO/CD-ROM.
5. Add a TPM 2.0 emulator with persistent state.
6. Add display, keyboard, pointer, and networking.
7. Test Windows installation and drivers.

Do not describe the prototype as a working Windows VM until those pieces exist.
