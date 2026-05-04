// AutoFillKill — silences -[NSAutoFillHeuristicController _debounceTextInputContextUpdate]
// inside the Diablo IV.exe wine subprocess only.
//
// Why: when D4 (running x86_64 under Rosetta inside Wine) opens a UI panel,
// winemac.so forwards a Cocoa "deactivate" event to NSApplication. AppKit
// posts an NSNotification, NSTextInputContext picks it up and calls
// _debounceTextInputContextUpdate on NSAutoFillHeuristicController, which
// arms a CFRunLoop timer. Rosetta's translation of that path deadlocks the
// main thread (sample shows 100% CPU on a single Rosetta runtime address,
// no progress for minutes).
//
// We swizzle the entry point to a no-op. AutoFill heuristics aren't useful
// for a game, and the chain that deadlocks is the only thing AppKit does
// with this method on a Wine-hosted process.
//
// We deliberately do NOT link AppKit — the framework gets loaded by
// winemac.so when needed, and forcing it via link dep adds ~hundreds of MB
// of resident memory after Rosetta translation, which pushes D4 past its
// per-process memory high watermark and macOS kills it. We use
// _dyld_register_func_for_add_image to apply the swizzle lazily when
// AppKit actually loads.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <string.h>

static void try_swizzle(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = NSClassFromString(@"NSAutoFillHeuristicController");
        if (!cls) return;
        SEL sel = NSSelectorFromString(@"_debounceTextInputContextUpdate");
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) return;
        IMP noop = imp_implementationWithBlock(^(__unused id self) { /* deliberately empty */ });
        method_setImplementation(m, noop);
        NSLog(@"[AutoFillKill] silenced -[NSAutoFillHeuristicController _debounceTextInputContextUpdate]");
    });
}

static void on_image_loaded(const struct mach_header *mh, intptr_t slide) {
    Dl_info info;
    if (dladdr(mh, &info) && info.dli_fname && strstr(info.dli_fname, "AppKit")) {
        try_swizzle();
    }
}

__attribute__((constructor))
static void d4mac_install_autofill_killer(void) {
    // Only activate inside the Diablo IV.exe wine subprocess. Battle.net's
    // CEF/Chromium UI legitimately uses the AutoFill chain for text input;
    // no-op'ing it there breaks BNet (exit code 13).
    BOOL isD4 = NO;
    for (NSString *a in [[NSProcessInfo processInfo] arguments]) {
        if ([a rangeOfString:@"Diablo IV.exe" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            isD4 = YES;
            break;
        }
    }
    if (!isD4) {
        return;
    }
    // Try now (in case AppKit is already in the address space).
    try_swizzle();
    // Also register a callback for any later AppKit load.
    _dyld_register_func_for_add_image(on_image_loaded);
    NSLog(@"[AutoFillKill] armed for Diablo IV.exe (waiting for AppKit)");
}
