/*
 * d4sync_shim — DYLD_INSERT interposer for Diablo IV (D4Mac)
 *
 * Workaround for an Apple Rosetta 2 TSO emulation lost-wakeup bug
 * (FB15880492 / FB21763885 / FB21838832) inside libd3dshared.dylib's
 * ThreadCallback. Symptom: D3DMetalWineThread parks forever in
 * os_sync_wait_on_address; pending_events at WineEventCallbacks+0x718
 * was already updated by translated wine but the native arm64 reader
 * sees a stale value due to cross-domain memory ordering.
 *
 * Strategy: interpose os_sync_wait_on_address with a bounded-timeout
 * variant. On ETIMEDOUT we re-read the predicate with acquire ordering;
 * if it changed, the wake was lost — return success. Otherwise re-park.
 * Lost-wakeup deadlock becomes a 50ms-bounded latency spike.
 *
 * Loaded only into the Diablo IV.exe wine subprocess (per-exec
 * DYLD_INSERT_LIBRARIES from wine's spawn_process patch); BNet/CEF
 * never sees it.
 */

#include <os/os_sync_wait_on_address.h>
#include <stdint.h>
#include <stddef.h>
#include <errno.h>

#define D4SYNC_TIMEOUT_NS  (50ULL * 1000 * 1000)

#define DYLD_INTERPOSE(replacement, original)                                  \
    __attribute__((used)) static struct {                                      \
        const void *replacement;                                               \
        const void *original;                                                  \
    } _interpose_##original __attribute__((section("__DATA,__interpose"))) = { \
        (const void *)(uintptr_t)&replacement,                                 \
        (const void *)(uintptr_t)&original                                     \
    }

static int d4sync_wait_on_address(void *addr, uint64_t value, size_t size,
                                  os_sync_wait_on_address_flags_t flags)
{
    for (;;) {
        int r = os_sync_wait_on_address_with_timeout(
            addr, value, size, flags,
            OS_CLOCK_MACH_ABSOLUTE_TIME, D4SYNC_TIMEOUT_NS);

        if (r >= 0) return r;
        if (errno != ETIMEDOUT) return r;

        switch (size) {
            case 4: {
                uint32_t cur = __atomic_load_n((uint32_t *)addr, __ATOMIC_ACQUIRE);
                if (cur != (uint32_t)value) return 0;
                break;
            }
            case 8: {
                uint64_t cur = __atomic_load_n((uint64_t *)addr, __ATOMIC_ACQUIRE);
                if (cur != value) return 0;
                break;
            }
            default:
                /* Unknown size: pass timeout through so caller can decide. */
                return r;
        }
    }
}

DYLD_INTERPOSE(d4sync_wait_on_address, os_sync_wait_on_address);
