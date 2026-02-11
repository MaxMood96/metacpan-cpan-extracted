/*
 * etcd_lock.h - Lock operation handlers for EV::Etcd
 */
#ifndef ETCD_LOCK_H
#define ETCD_LOCK_H

#include "etcd_common.h"

/* Lock response handlers */
void process_lock_response(pTHX_ pending_call_t *pc);
void process_unlock_response(pTHX_ pending_call_t *pc);

#endif /* ETCD_LOCK_H */
