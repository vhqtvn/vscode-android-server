#define _GNU_SOURCE

#include <stddef.h>
#include <unistd.h>
#include <stdio.h>
#include <dlfcn.h>
#include <string.h>

typedef ssize_t (*readlink_t)(const char *restrict pathname, char *restrict buf,
                        size_t bufsiz);

ssize_t readlink(const char *restrict path, char *restrict buffer, size_t size) {
    static readlink_t orig = NULL;
    int r;
    if(!orig) orig = dlsym(RTLD_NEXT, "readlink");
    r = (orig)(path, buffer, size);
    if(r>=10 && r<size && !strcmp(path, "/proc/self/exe")
        && buffer[r-10]=='/'
        && buffer[r-9]=='n'
        && buffer[r-8]=='o'
        && buffer[r-7]=='d'
        && buffer[r-6]=='e'
        && buffer[r-5]=='.'
        && buffer[r-4]=='o'
        && buffer[r-3]=='r'
        && buffer[r-2]=='i'
        && buffer[r-1]=='g'
    ) {
        r-=5;
        buffer[r]=0;
    }
    return r;
}