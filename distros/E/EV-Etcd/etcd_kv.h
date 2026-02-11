/*
 * etcd_kv.h - KV operation response handlers for EV::Etcd
 */
#ifndef ETCD_KV_H
#define ETCD_KV_H

#include "etcd_common.h"

/* Response handlers for KV operations */
void process_range_response(pTHX_ pending_call_t *pc);
void process_put_response(pTHX_ pending_call_t *pc);
void process_delete_response(pTHX_ pending_call_t *pc);
void process_compact_response(pTHX_ pending_call_t *pc);

#endif /* ETCD_KV_H */
