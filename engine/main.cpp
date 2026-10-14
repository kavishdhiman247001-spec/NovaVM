#include <Hypervisor/Hypervisor.h>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <cstdint>

static bool check(hv_return_t result, const char* operation) {
    if (result == HV_SUCCESS) {
        std::cout << "[OK] " << operation << '\n';
        return true;
    }

    std::cerr << "[ERROR] " << operation
              << " failed: " << result << '\n';
    return false;
}

int main() {
    constexpr size_t PAGE_SIZE = 4096;
    constexpr uint64_t GUEST_ADDRESS = 0x1000;

    const uint8_t guest_code[] = {
        0xB8, 0x2A, 0x00, 0x00, 0x00,
        0xF4
    };

    void* ram = nullptr;
    hv_vcpuid_t vcpu = 0;
    bool vm_created = false;
    bool memory_mapped = false;
    bool vcpu_created = false;
    int result = 1;

    std::cout << "NovaVM native engine\n";

    if (!check(hv_vm_create(0), "Create VM"))
        return 1;

    vm_created = true;

    if (posix_memalign(&ram, PAGE_SIZE, PAGE_SIZE) != 0) {
        std::cerr << "[ERROR] Allocate guest RAM\n";
        goto cleanup;
    }

    std::memset(ram, 0, PAGE_SIZE);

    // Example guest bytes: MOV EAX, 42; HLT.
    // Declared before any goto can jump to cleanup.
    std::memcpy(ram, guest_code, sizeof(guest_code));

    if (!check(
            hv_vm_map(
                ram,
                GUEST_ADDRESS,
                PAGE_SIZE,
                HV_MEMORY_READ |
                HV_MEMORY_WRITE |
                HV_MEMORY_EXEC
            ),
            "Map guest RAM")) {
        goto cleanup;
    }

    memory_mapped = true;

    if (!check(
            hv_vcpu_create(&vcpu, HV_VCPU_DEFAULT),
            "Create virtual CPU")) {
        goto cleanup;
    }

    vcpu_created = true;

    std::cout << "[OK] Guest code staged at physical address 0x"
              << std::hex << GUEST_ADDRESS << std::dec << '\n';

    std::cout << "\nNovaVM milestone passed:\n"
              << "  VM created\n"
              << "  Guest RAM mapped\n"
              << "  Virtual CPU created\n"
              << "  Guest instruction bytes loaded\n"
              << "  Guest instructions NOT executed yet\n";

    result = 0;

cleanup:
    if (vcpu_created)
        check(hv_vcpu_destroy(vcpu), "Destroy virtual CPU");

    if (memory_mapped)
        check(hv_vm_unmap(GUEST_ADDRESS, PAGE_SIZE), "Unmap guest RAM");

    std::free(ram);

    if (vm_created)
        check(hv_vm_destroy(), "Destroy VM");

    return result;
}
