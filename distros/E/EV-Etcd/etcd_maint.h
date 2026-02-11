/*
 * etcd_maint.h - Maintenance operation handlers for EV::Etcd
 */
#ifndef ETCD_MAINT_H
#define ETCD_MAINT_H

#include "etcd_common.h"

/* Maintenance response handlers */
void process_status_response(pTHX_ pending_call_t *pc);
void process_alarm_response(pTHX_ pending_call_t *pc);
void process_defragment_response(pTHX_ pending_call_t *pc);
void process_hash_kv_response(pTHX_ pending_call_t *pc);
void process_move_leader_response(pTHX_ pending_call_t *pc);
void process_auth_status_response(pTHX_ pending_call_t *pc);

#endif /* ETCD_MAINT_H */
