/*
 * election.pb-c.h - Protocol Buffers for etcd v3 Election service
 *
 * Generated manually based on etcd/api/v3election/v3electionpb/v3election.proto
 */
#ifndef ELECTION_PB_C_H
#define ELECTION_PB_C_H

#include <protobuf-c/protobuf-c.h>
#include "kv.pb-c.h"
#include "rpc.pb-c.h"

PROTOBUF_C__BEGIN_DECLS

/* Forward declarations */
typedef struct V3electionpb__LeaderKey V3electionpb__LeaderKey;
typedef struct V3electionpb__CampaignRequest V3electionpb__CampaignRequest;
typedef struct V3electionpb__CampaignResponse V3electionpb__CampaignResponse;
typedef struct V3electionpb__ProclaimRequest V3electionpb__ProclaimRequest;
typedef struct V3electionpb__ProclaimResponse V3electionpb__ProclaimResponse;
typedef struct V3electionpb__LeaderRequest V3electionpb__LeaderRequest;
typedef struct V3electionpb__LeaderResponse V3electionpb__LeaderResponse;
typedef struct V3electionpb__ResignRequest V3electionpb__ResignRequest;
typedef struct V3electionpb__ResignResponse V3electionpb__ResignResponse;
typedef struct V3electionpb__ProclaimLeaderRequest V3electionpb__ProclaimLeaderRequest;

/*
 * LeaderKey represents the leader's key and associated lease
 */
struct V3electionpb__LeaderKey {
    ProtobufCMessage base;
    /* name is the election identifier for the leadership */
    ProtobufCBinaryData name;
    /* key is an opaque key representing the ownership of the election */
    ProtobufCBinaryData key;
    /* rev is the creation revision of the key */
    int64_t rev;
    /* lease is the lease ID of the election leader */
    int64_t lease;
};
#define V3ELECTIONPB__LEADER_KEY__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&v3electionpb__leader_key__descriptor) \
    , {0,NULL}, {0,NULL}, 0, 0 }

/*
 * CampaignRequest - campaign for leadership
 */
struct V3electionpb__CampaignRequest {
    ProtobufCMessage base;
    /* name is the election's identifier for the campaign */
    ProtobufCBinaryData name;
    /* lease is the ID of the lease attached to leadership */
    int64_t lease;
    /* value is the initial value to set for the leader key */
    ProtobufCBinaryData value;
};
#define V3ELECTIONPB__CAMPAIGN_REQUEST__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&v3electionpb__campaign_request__descriptor) \
    , {0,NULL}, 0, {0,NULL} }

/*
 * CampaignResponse - result of campaign
 */
struct V3electionpb__CampaignResponse {
    ProtobufCMessage base;
    Etcdserverpb__ResponseHeader *header;
    /* leader describes the resources used for holding leadership */
    V3electionpb__LeaderKey *leader;
};
#define V3ELECTIONPB__CAMPAIGN_RESPONSE__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&v3electionpb__campaign_response__descriptor) \
    , NULL, NULL }

/*
 * LeaderRequest - get the current leader
 */
struct V3electionpb__LeaderRequest {
    ProtobufCMessage base;
    /* name is the election identifier for the leadership info */
    ProtobufCBinaryData name;
};
#define V3ELECTIONPB__LEADER_REQUEST__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&v3electionpb__leader_request__descriptor) \
    , {0,NULL} }

/*
 * LeaderResponse - current leader info
 */
struct V3electionpb__LeaderResponse {
    ProtobufCMessage base;
    Etcdserverpb__ResponseHeader *header;
    /* kv is the key-value pair representing the latest leader */
    Mvccpb__KeyValue *kv;
};
#define V3ELECTIONPB__LEADER_RESPONSE__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&v3electionpb__leader_response__descriptor) \
    , NULL, NULL }

/*
 * ResignRequest - give up leadership
 */
struct V3electionpb__ResignRequest {
    ProtobufCMessage base;
    /* leader is the leadership to relinquish */
    V3electionpb__LeaderKey *leader;
};
#define V3ELECTIONPB__RESIGN_REQUEST__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&v3electionpb__resign_request__descriptor) \
    , NULL }

/*
 * ResignResponse
 */
struct V3electionpb__ResignResponse {
    ProtobufCMessage base;
    Etcdserverpb__ResponseHeader *header;
};
#define V3ELECTIONPB__RESIGN_RESPONSE__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&v3electionpb__resign_response__descriptor) \
    , NULL }

/*
 * ProclaimRequest - update leader's value
 */
struct V3electionpb__ProclaimRequest {
    ProtobufCMessage base;
    /* leader is the leadership key */
    V3electionpb__LeaderKey *leader;
    /* value is the new value to set for the key */
    ProtobufCBinaryData value;
};
#define V3ELECTIONPB__PROCLAIM_REQUEST__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&v3electionpb__proclaim_request__descriptor) \
    , NULL, {0,NULL} }

/*
 * ProclaimResponse
 */
struct V3electionpb__ProclaimResponse {
    ProtobufCMessage base;
    Etcdserverpb__ResponseHeader *header;
};
#define V3ELECTIONPB__PROCLAIM_RESPONSE__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&v3electionpb__proclaim_response__descriptor) \
    , NULL }

/* Descriptors */
extern const ProtobufCMessageDescriptor v3electionpb__leader_key__descriptor;
extern const ProtobufCMessageDescriptor v3electionpb__campaign_request__descriptor;
extern const ProtobufCMessageDescriptor v3electionpb__campaign_response__descriptor;
extern const ProtobufCMessageDescriptor v3electionpb__leader_request__descriptor;
extern const ProtobufCMessageDescriptor v3electionpb__leader_response__descriptor;
extern const ProtobufCMessageDescriptor v3electionpb__resign_request__descriptor;
extern const ProtobufCMessageDescriptor v3electionpb__resign_response__descriptor;
extern const ProtobufCMessageDescriptor v3electionpb__proclaim_request__descriptor;
extern const ProtobufCMessageDescriptor v3electionpb__proclaim_response__descriptor;

/* Pack/Unpack functions */
size_t v3electionpb__leader_key__get_packed_size(const V3electionpb__LeaderKey *message);
size_t v3electionpb__leader_key__pack(const V3electionpb__LeaderKey *message, uint8_t *out);
V3electionpb__LeaderKey *v3electionpb__leader_key__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void v3electionpb__leader_key__free_unpacked(V3electionpb__LeaderKey *message, ProtobufCAllocator *allocator);

size_t v3electionpb__campaign_request__get_packed_size(const V3electionpb__CampaignRequest *message);
size_t v3electionpb__campaign_request__pack(const V3electionpb__CampaignRequest *message, uint8_t *out);
V3electionpb__CampaignRequest *v3electionpb__campaign_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void v3electionpb__campaign_request__free_unpacked(V3electionpb__CampaignRequest *message, ProtobufCAllocator *allocator);

size_t v3electionpb__campaign_response__get_packed_size(const V3electionpb__CampaignResponse *message);
size_t v3electionpb__campaign_response__pack(const V3electionpb__CampaignResponse *message, uint8_t *out);
V3electionpb__CampaignResponse *v3electionpb__campaign_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void v3electionpb__campaign_response__free_unpacked(V3electionpb__CampaignResponse *message, ProtobufCAllocator *allocator);

size_t v3electionpb__leader_request__get_packed_size(const V3electionpb__LeaderRequest *message);
size_t v3electionpb__leader_request__pack(const V3electionpb__LeaderRequest *message, uint8_t *out);
V3electionpb__LeaderRequest *v3electionpb__leader_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void v3electionpb__leader_request__free_unpacked(V3electionpb__LeaderRequest *message, ProtobufCAllocator *allocator);

size_t v3electionpb__leader_response__get_packed_size(const V3electionpb__LeaderResponse *message);
size_t v3electionpb__leader_response__pack(const V3electionpb__LeaderResponse *message, uint8_t *out);
V3electionpb__LeaderResponse *v3electionpb__leader_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void v3electionpb__leader_response__free_unpacked(V3electionpb__LeaderResponse *message, ProtobufCAllocator *allocator);

size_t v3electionpb__resign_request__get_packed_size(const V3electionpb__ResignRequest *message);
size_t v3electionpb__resign_request__pack(const V3electionpb__ResignRequest *message, uint8_t *out);
V3electionpb__ResignRequest *v3electionpb__resign_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void v3electionpb__resign_request__free_unpacked(V3electionpb__ResignRequest *message, ProtobufCAllocator *allocator);

size_t v3electionpb__resign_response__get_packed_size(const V3electionpb__ResignResponse *message);
size_t v3electionpb__resign_response__pack(const V3electionpb__ResignResponse *message, uint8_t *out);
V3electionpb__ResignResponse *v3electionpb__resign_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void v3electionpb__resign_response__free_unpacked(V3electionpb__ResignResponse *message, ProtobufCAllocator *allocator);

size_t v3electionpb__proclaim_request__get_packed_size(const V3electionpb__ProclaimRequest *message);
size_t v3electionpb__proclaim_request__pack(const V3electionpb__ProclaimRequest *message, uint8_t *out);
V3electionpb__ProclaimRequest *v3electionpb__proclaim_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void v3electionpb__proclaim_request__free_unpacked(V3electionpb__ProclaimRequest *message, ProtobufCAllocator *allocator);

size_t v3electionpb__proclaim_response__get_packed_size(const V3electionpb__ProclaimResponse *message);
size_t v3electionpb__proclaim_response__pack(const V3electionpb__ProclaimResponse *message, uint8_t *out);
V3electionpb__ProclaimResponse *v3electionpb__proclaim_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void v3electionpb__proclaim_response__free_unpacked(V3electionpb__ProclaimResponse *message, ProtobufCAllocator *allocator);

PROTOBUF_C__END_DECLS

#endif /* ELECTION_PB_C_H */
