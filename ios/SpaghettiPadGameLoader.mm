#import <Foundation/Foundation.h>
#include <SDL.h>
#include <dlfcn.h>
#include <stdio.h>

static int ModuleFailure(const char* detail) {
    fprintf(stderr, "[SpaghettiPad] Game module load failed: %s\n", detail ? detail : "unknown error");
    SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Unable to start the game",
                             "The game module is missing or incompatible. Rebuild and sign the complete app.", nullptr);
    return 1;
}

extern "C" int SDL_main(int argc, char** argv) {
    NSString* path = [[[NSBundle mainBundle] bundlePath]
        stringByAppendingPathComponent:@"Frameworks/SpaghettiGame.dylib"];
    // Keep the handle alive: game callbacks and global objects outlive this call.
    static void* module = nullptr;
    module = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
    if (!module) {
        return ModuleFailure(dlerror());
    }
    dlerror();
    auto entry = reinterpret_cast<int (*)(int, char**)>(dlsym(module, "SDL_main"));
    const char* error = dlerror();
    if (error || !entry || entry == &SDL_main) {
        return ModuleFailure(error ? error : "missing or recursive SDL_main entry");
    }
    return entry(argc, argv);
}
