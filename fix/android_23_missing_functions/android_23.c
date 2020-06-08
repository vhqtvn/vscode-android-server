//https://chromium.googlesource.com/android_tools/+/af1c5a4cd6329ccdcf8c2bc93d9eea02f9d74869/ndk/platforms/android-16/arch-arm/usr/include/linux/in6.h
#include <linux/types.h>
#include <pthread.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#if __GXX_WEAK__ && _GLIBCXX_GTHREAD_USE_WEAK
# ifndef __gthrw_pragma
#  define __gthrw_pragma(pragma)
# endif
# define __gthrw2(name,name2,type) \
  static __typeof(type) name __attribute__ ((__weakref__(#name2))); \
  __gthrw_pragma(weak type)
# define __gthrw_(name) __gthrw_ ## name
#else
# define __gthrw2(name,name2,type)
# define __gthrw_(name) name
#endif

typedef pthread_t __gthread_t;
typedef pthread_key_t __gthread_key_t;
typedef pthread_once_t __gthread_once_t;
typedef pthread_mutex_t __gthread_mutex_t;
typedef pthread_mutex_t __gthread_recursive_mutex_t;
typedef pthread_cond_t __gthread_cond_t;
typedef struct timespec __gthread_time_t;

typedef unsigned int word __attribute__((mode(word)));
typedef unsigned int pointer __attribute__((mode(pointer)));

struct in6_addr
{
 union
 {
 __u8 u6_addr8[16];
 __u16 u6_addr16[8];
 __u32 u6_addr32[4];
 } in6_u;
#define s6_addr in6_u.u6_addr8
#define s6_addr16 in6_u.u6_addr16
#define s6_addr32 in6_u.u6_addr32
};
const struct in6_addr in6addr_any = { { { 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } } };

extern void abort ();

static volatile int __gthread_active = -1;
static void
__gthread_trigger (void)
{
  __gthread_active = 1;
}

static inline int
__gthread_active_p (void)
{
 //  static pthread_mutex_t __gthread_active_mutex = PTHREAD_MUTEX_INITIALIZER;
 //  static pthread_once_t __gthread_active_once = PTHREAD_ONCE_INIT;
 //  /* Avoid reading __gthread_active twice on the main code path.  */
 //  int __gthread_active_latest_value = __gthread_active;
 //  /* This test is not protected to avoid taking a lock on the main code
 //     path so every update of __gthread_active in a threaded program must
 //     be atomic with regard to the result of the test.  */
 //  if (__builtin_expect (__gthread_active_latest_value < 0, 0))
 //    {
 //      if (__gthrw_(pthread_once))
	// {
	//   /* If this really is a threaded program, then we must ensure that
	//      __gthread_active has been set to 1 before exiting this block.  */
	//   __gthrw_(pthread_mutex_lock) (&__gthread_active_mutex);
	//   __gthrw_(pthread_once) (&__gthread_active_once, __gthread_trigger);
	//   __gthrw_(pthread_mutex_unlock) (&__gthread_active_mutex);
	// }
 //      /* Make sure we'll never enter this block again.  */
 //      if (__gthread_active < 0)
	// __gthread_active = 0;
 //      __gthread_active_latest_value = __gthread_active;
 //    }
 //  return __gthread_active_latest_value != 0;
	return 0;
}


void pthread_barrier_wait(){fprintf(stderr,"called pthread_barrier_wait\n");exit(-1);}
void pthread_barrier_init(){fprintf(stderr,"called pthread_barrier_init\n");exit(-1);}
void pthread_barrier_destroy(){fprintf(stderr,"called pthread_barrier_destroy\n");exit(-1);}

struct __emutls_object
{
  word size;
  word align;
  union {
    pointer offset;
    void *ptr;
  } loc;
  void *templ;
};

static void *
emutls_alloc (struct __emutls_object *obj)
{
  void *ptr;
  void *ret;
  /* We could use here posix_memalign if available and adjust
     emutls_destroy accordingly.  */
  if (obj->align <= sizeof (void *))
    {
      ptr = malloc (obj->size + sizeof (void *));
      if (ptr == NULL)
	abort ();
      ((void **) ptr)[0] = ptr;
      ret = ptr + sizeof (void *);
    }
  else
    {
      ptr = malloc (obj->size + sizeof (void *) + obj->align - 1);
      if (ptr == NULL)
	abort ();
      ret = (void *) (((pointer) (ptr + sizeof (void *) + obj->align - 1))
		      & ~(pointer)(obj->align - 1));
      ((void **) ret)[-1] = ptr;
    }
  if (obj->templ)
    memcpy (ret, obj->templ, obj->size);
  else
    memset (ret, 0, obj->size);
  return ret;
}


void *
__emutls_get_address (struct __emutls_object *obj)
{
  if (! __gthread_active_p ())
    {
      if (__builtin_expect (obj->loc.ptr == NULL, 0))
	obj->loc.ptr = emutls_alloc (obj);
      return obj->loc.ptr;
    }
#ifndef __GTHREADS
  abort ();
#else
  pointer offset = __atomic_load_n (&obj->loc.offset, __ATOMIC_ACQUIRE);
  if (__builtin_expect (offset == 0, 0))
    {
      static __gthread_once_t once = __GTHREAD_ONCE_INIT;
      __gthread_once (&once, emutls_init);
      __gthread_mutex_lock (&emutls_mutex);
      offset = obj->loc.offset;
      if (offset == 0)
	{
	  offset = ++emutls_size;
	  __atomic_store_n (&obj->loc.offset, offset, __ATOMIC_RELEASE);
	}
      __gthread_mutex_unlock (&emutls_mutex);
    }
  struct __emutls_array *arr = __gthread_getspecific (emutls_key);
  const pointer hdr_size = sizeof (struct __emutls_array) / sizeof (void *);
  if (__builtin_expect (arr == NULL, 0))
    {
      pointer size = offset + 32;
      arr = calloc (size + hdr_size, sizeof (void *));
      if (arr == NULL)
	abort ();
      arr->skip_destructor_rounds = EMUTLS_SKIP_DESTRUCTOR_ROUNDS;
      arr->size = size;
      __gthread_setspecific (emutls_key, (void *) arr);
    }
  else if (__builtin_expect (offset > arr->size, 0))
    {
      pointer orig_size = arr->size;
      pointer size = orig_size * 2;
      if (offset > size)
	size = offset + 32;
      arr = realloc (arr, (size + hdr_size) * sizeof (void *));
      if (arr == NULL)
	abort ();
      arr->size = size;
      memset (arr->data + orig_size, 0,
	      (size - orig_size) * sizeof (void *));
      __gthread_setspecific (emutls_key, (void *) arr);
    }
  void *ret = arr->data[offset - 1];
  if (__builtin_expect (ret == NULL, 0))
    {
      ret = emutls_alloc (obj);
      arr->data[offset - 1] = ret;
    }
  return ret;
#endif
}
