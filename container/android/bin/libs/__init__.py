import os

def argfix(args):
    is_32bit = os.getenv('ANDROID_ARCH') in ['arm','armeabi-v7a','x86']
    to_add = '-m32' if is_32bit else '-m64'
    to_remove = ['-m64' if is_32bit else '-m32']
    args = [to_add] + args
    for x in to_remove:
        try:
            while True:
                idx = args.index(x)
                args.pop(idx)
        except:
            pass
    return args
