#ifndef _PTHREAD_INTERNAL_H_
#define _PTHREAD_INTERNAL_H_

#include <pthread.h>

struct pthread_internal_t {
  struct pthread_internal_t* next;
  struct pthread_internal_t* prev;

  pid_t tid;

  void** tls;

  volatile pthread_attr_t attr;

  __pthread_cleanup_t* cleanup_stack;

  void* (*start_routine)(void*);
  void* start_routine_arg;
  void* return_value;

  void* alternate_signal_stack;

  /*
   * The dynamic linker implements dlerror(3), which makes it hard for us to implement this
   * per-thread buffer by simply using malloc(3) and free(3).
   */
#define __BIONIC_DLERROR_BUFFER_SIZE 508
  char dlerror_buffer[__BIONIC_DLERROR_BUFFER_SIZE];
	
	//  ugly hack: use last 4 bytes of dlerror_buffer as cancel_lock
	pthread_mutex_t cancel_lock; 
};

/* Has the thread a cancellation request? */
#define PTHREAD_ATTR_FLAG_CANCEL_PENDING 0x00000008

/* Has the thread enabled cancellation? */
#define PTHREAD_ATTR_FLAG_CANCEL_ENABLE 0x00000010

/* Has the thread asyncronous cancellation? */
#define PTHREAD_ATTR_FLAG_CANCEL_ASYNCRONOUS 0x00000020

/* Has the thread a cancellation handler? */
#define PTHREAD_ATTR_FLAG_CANCEL_HANDLER 0x00000040

struct pthread_internal_t *__pthread_getid ( pthread_t );

static int __pthread_do_cancel (struct pthread_internal_t *);

void pthread_init(void);

static void
call_exit (void)
{
  pthread_exit (0);
}

static int
__pthread_do_cancel (struct pthread_internal_t *p)
{
	
	if(p == (struct pthread_internal_t *)pthread_self())
    call_exit ();
  else if(p->attr.flags & PTHREAD_ATTR_FLAG_CANCEL_HANDLER)
    pthread_kill((pthread_t)p, SIGRTMIN);
	else
		pthread_kill((pthread_t)p, SIGTERM);

  return 0;
}

static int
pthread_cancel (pthread_t t)
{
  int err = 0;
  struct pthread_internal_t *p = (struct pthread_internal_t*) t;
	
	pthread_init();
	
  pthread_mutex_lock (&p->cancel_lock);
  if (p->attr.flags & PTHREAD_ATTR_FLAG_CANCEL_PENDING)
    {
      pthread_mutex_unlock (&p->cancel_lock);
      return 0;
    }
    
  p->attr.flags |= PTHREAD_ATTR_FLAG_CANCEL_PENDING;

  if (!(p->attr.flags & PTHREAD_ATTR_FLAG_CANCEL_ENABLE))
    {
      pthread_mutex_unlock (&p->cancel_lock);
      return 0;
    }

  if (p->attr.flags & PTHREAD_ATTR_FLAG_CANCEL_ASYNCRONOUS) {
		pthread_mutex_unlock (&p->cancel_lock);
    err = __pthread_do_cancel (p);
	} else {
		// DEFERRED CANCEL NOT IMPLEMENTED YET
		pthread_mutex_unlock (&p->cancel_lock);
	}

  return err;
}

#endif /* _PTHREAD_INTERNAL_H_ */
