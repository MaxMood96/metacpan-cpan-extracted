/*
 * cluster.pb-c.h - Protocol Buffers for etcd v3 Cluster service
 *
 * Generated manually based on etcd/api/etcdserverpb/rpc.proto
 */
#ifndef CLUSTER_PB_C_H
#define CLUSTER_PB_C_H

#include <protobuf-c/protobuf-c.h>
#include "rpc.pb-c.h"

PROTOBUF_C__BEGIN_DECLS

/* Forward declarations */
typedef struct Etcdserverpb__Member Etcdserverpb__Member;
typedef struct Etcdserverpb__MemberAddRequest Etcdserverpb__MemberAddRequest;
typedef struct Etcdserverpb__MemberAddResponse Etcdserverpb__MemberAddResponse;
typedef struct Etcdserverpb__MemberRemoveRequest Etcdserverpb__MemberRemoveRequest;
typedef struct Etcdserverpb__MemberRemoveResponse Etcdserverpb__MemberRemoveResponse;
typedef struct Etcdserverpb__MemberUpdateRequest Etcdserverpb__MemberUpdateRequest;
typedef struct Etcdserverpb__MemberUpdateResponse Etcdserverpb__MemberUpdateResponse;
typedef struct Etcdserverpb__MemberListRequest Etcdserverpb__MemberListRequest;
typedef struct Etcdserverpb__MemberListResponse Etcdserverpb__MemberListResponse;
typedef struct Etcdserverpb__MemberPromoteRequest Etcdserverpb__MemberPromoteRequest;
typedef struct Etcdserverpb__MemberPromoteResponse Etcdserverpb__MemberPromoteResponse;

/*
 * Member represents a cluster member
 */
struct Etcdserverpb__Member {
    ProtobufCMessage base;
    /* ID is the member ID for this member */
    uint64_t id;
    /* name is the human-readable name of the member */
    char *name;
    /* peerURLs is the list of URLs the member exposes to the cluster for communication */
    size_t n_peer_urls;
    char **peer_urls;
    /* clientURLs is the list of URLs the member exposes to clients for communication */
    size_t n_client_urls;
    char **client_urls;
    /* isLearner indicates if the member is a learner */
    protobuf_c_boolean is_learner;
};
#define ETCDSERVERPB__MEMBER__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member__descriptor) \
    , 0, NULL, 0, NULL, 0, NULL, 0 }

/*
 * MemberAddRequest
 */
struct Etcdserverpb__MemberAddRequest {
    ProtobufCMessage base;
    /* peerURLs is the list of URLs the added member will use to communicate with the cluster */
    size_t n_peer_urls;
    char **peer_urls;
    /* isLearner indicates if the added member is a learner */
    protobuf_c_boolean is_learner;
};
#define ETCDSERVERPB__MEMBER_ADD_REQUEST__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member_add_request__descriptor) \
    , 0, NULL, 0 }

/*
 * MemberAddResponse
 */
struct Etcdserverpb__MemberAddResponse {
    ProtobufCMessage base;
    Etcdserverpb__ResponseHeader *header;
    /* member is the member information for the added member */
    Etcdserverpb__Member *member;
    /* members is a list of all members after adding the new member */
    size_t n_members;
    Etcdserverpb__Member **members;
};
#define ETCDSERVERPB__MEMBER_ADD_RESPONSE__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member_add_response__descriptor) \
    , NULL, NULL, 0, NULL }

/*
 * MemberRemoveRequest
 */
struct Etcdserverpb__MemberRemoveRequest {
    ProtobufCMessage base;
    /* ID is the member ID of the member to remove */
    uint64_t id;
};
#define ETCDSERVERPB__MEMBER_REMOVE_REQUEST__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member_remove_request__descriptor) \
    , 0 }

/*
 * MemberRemoveResponse
 */
struct Etcdserverpb__MemberRemoveResponse {
    ProtobufCMessage base;
    Etcdserverpb__ResponseHeader *header;
    /* members is a list of all members after removing the member */
    size_t n_members;
    Etcdserverpb__Member **members;
};
#define ETCDSERVERPB__MEMBER_REMOVE_RESPONSE__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member_remove_response__descriptor) \
    , NULL, 0, NULL }

/*
 * MemberUpdateRequest
 */
struct Etcdserverpb__MemberUpdateRequest {
    ProtobufCMessage base;
    /* ID is the member ID of the member to update */
    uint64_t id;
    /* peerURLs is the new list of URLs the member will use to communicate with the cluster */
    size_t n_peer_urls;
    char **peer_urls;
};
#define ETCDSERVERPB__MEMBER_UPDATE_REQUEST__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member_update_request__descriptor) \
    , 0, 0, NULL }

/*
 * MemberUpdateResponse
 */
struct Etcdserverpb__MemberUpdateResponse {
    ProtobufCMessage base;
    Etcdserverpb__ResponseHeader *header;
    /* members is a list of all members after updating the member */
    size_t n_members;
    Etcdserverpb__Member **members;
};
#define ETCDSERVERPB__MEMBER_UPDATE_RESPONSE__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member_update_response__descriptor) \
    , NULL, 0, NULL }

/*
 * MemberListRequest
 */
struct Etcdserverpb__MemberListRequest {
    ProtobufCMessage base;
    /* linearizable indicates if the member list should be linearizable */
    protobuf_c_boolean linearizable;
};
#define ETCDSERVERPB__MEMBER_LIST_REQUEST__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member_list_request__descriptor) \
    , 0 }

/*
 * MemberListResponse
 */
struct Etcdserverpb__MemberListResponse {
    ProtobufCMessage base;
    Etcdserverpb__ResponseHeader *header;
    /* members is a list of all members in the cluster */
    size_t n_members;
    Etcdserverpb__Member **members;
};
#define ETCDSERVERPB__MEMBER_LIST_RESPONSE__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member_list_response__descriptor) \
    , NULL, 0, NULL }

/*
 * MemberPromoteRequest
 */
struct Etcdserverpb__MemberPromoteRequest {
    ProtobufCMessage base;
    /* ID is the member ID of the member to promote */
    uint64_t id;
};
#define ETCDSERVERPB__MEMBER_PROMOTE_REQUEST__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member_promote_request__descriptor) \
    , 0 }

/*
 * MemberPromoteResponse
 */
struct Etcdserverpb__MemberPromoteResponse {
    ProtobufCMessage base;
    Etcdserverpb__ResponseHeader *header;
    /* members is a list of all members after promoting the member */
    size_t n_members;
    Etcdserverpb__Member **members;
};
#define ETCDSERVERPB__MEMBER_PROMOTE_RESPONSE__INIT \
    { PROTOBUF_C_MESSAGE_INIT (&etcdserverpb__member_promote_response__descriptor) \
    , NULL, 0, NULL }

/* Descriptors */
extern const ProtobufCMessageDescriptor etcdserverpb__member__descriptor;
extern const ProtobufCMessageDescriptor etcdserverpb__member_add_request__descriptor;
extern const ProtobufCMessageDescriptor etcdserverpb__member_add_response__descriptor;
extern const ProtobufCMessageDescriptor etcdserverpb__member_remove_request__descriptor;
extern const ProtobufCMessageDescriptor etcdserverpb__member_remove_response__descriptor;
extern const ProtobufCMessageDescriptor etcdserverpb__member_update_request__descriptor;
extern const ProtobufCMessageDescriptor etcdserverpb__member_update_response__descriptor;
extern const ProtobufCMessageDescriptor etcdserverpb__member_list_request__descriptor;
extern const ProtobufCMessageDescriptor etcdserverpb__member_list_response__descriptor;
extern const ProtobufCMessageDescriptor etcdserverpb__member_promote_request__descriptor;
extern const ProtobufCMessageDescriptor etcdserverpb__member_promote_response__descriptor;

/* Pack/Unpack functions */
size_t etcdserverpb__member__get_packed_size(const Etcdserverpb__Member *message);
size_t etcdserverpb__member__pack(const Etcdserverpb__Member *message, uint8_t *out);
Etcdserverpb__Member *etcdserverpb__member__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member__free_unpacked(Etcdserverpb__Member *message, ProtobufCAllocator *allocator);

size_t etcdserverpb__member_add_request__get_packed_size(const Etcdserverpb__MemberAddRequest *message);
size_t etcdserverpb__member_add_request__pack(const Etcdserverpb__MemberAddRequest *message, uint8_t *out);
Etcdserverpb__MemberAddRequest *etcdserverpb__member_add_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member_add_request__free_unpacked(Etcdserverpb__MemberAddRequest *message, ProtobufCAllocator *allocator);

size_t etcdserverpb__member_add_response__get_packed_size(const Etcdserverpb__MemberAddResponse *message);
size_t etcdserverpb__member_add_response__pack(const Etcdserverpb__MemberAddResponse *message, uint8_t *out);
Etcdserverpb__MemberAddResponse *etcdserverpb__member_add_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member_add_response__free_unpacked(Etcdserverpb__MemberAddResponse *message, ProtobufCAllocator *allocator);

size_t etcdserverpb__member_remove_request__get_packed_size(const Etcdserverpb__MemberRemoveRequest *message);
size_t etcdserverpb__member_remove_request__pack(const Etcdserverpb__MemberRemoveRequest *message, uint8_t *out);
Etcdserverpb__MemberRemoveRequest *etcdserverpb__member_remove_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member_remove_request__free_unpacked(Etcdserverpb__MemberRemoveRequest *message, ProtobufCAllocator *allocator);

size_t etcdserverpb__member_remove_response__get_packed_size(const Etcdserverpb__MemberRemoveResponse *message);
size_t etcdserverpb__member_remove_response__pack(const Etcdserverpb__MemberRemoveResponse *message, uint8_t *out);
Etcdserverpb__MemberRemoveResponse *etcdserverpb__member_remove_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member_remove_response__free_unpacked(Etcdserverpb__MemberRemoveResponse *message, ProtobufCAllocator *allocator);

size_t etcdserverpb__member_update_request__get_packed_size(const Etcdserverpb__MemberUpdateRequest *message);
size_t etcdserverpb__member_update_request__pack(const Etcdserverpb__MemberUpdateRequest *message, uint8_t *out);
Etcdserverpb__MemberUpdateRequest *etcdserverpb__member_update_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member_update_request__free_unpacked(Etcdserverpb__MemberUpdateRequest *message, ProtobufCAllocator *allocator);

size_t etcdserverpb__member_update_response__get_packed_size(const Etcdserverpb__MemberUpdateResponse *message);
size_t etcdserverpb__member_update_response__pack(const Etcdserverpb__MemberUpdateResponse *message, uint8_t *out);
Etcdserverpb__MemberUpdateResponse *etcdserverpb__member_update_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member_update_response__free_unpacked(Etcdserverpb__MemberUpdateResponse *message, ProtobufCAllocator *allocator);

size_t etcdserverpb__member_list_request__get_packed_size(const Etcdserverpb__MemberListRequest *message);
size_t etcdserverpb__member_list_request__pack(const Etcdserverpb__MemberListRequest *message, uint8_t *out);
Etcdserverpb__MemberListRequest *etcdserverpb__member_list_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member_list_request__free_unpacked(Etcdserverpb__MemberListRequest *message, ProtobufCAllocator *allocator);

size_t etcdserverpb__member_list_response__get_packed_size(const Etcdserverpb__MemberListResponse *message);
size_t etcdserverpb__member_list_response__pack(const Etcdserverpb__MemberListResponse *message, uint8_t *out);
Etcdserverpb__MemberListResponse *etcdserverpb__member_list_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member_list_response__free_unpacked(Etcdserverpb__MemberListResponse *message, ProtobufCAllocator *allocator);

size_t etcdserverpb__member_promote_request__get_packed_size(const Etcdserverpb__MemberPromoteRequest *message);
size_t etcdserverpb__member_promote_request__pack(const Etcdserverpb__MemberPromoteRequest *message, uint8_t *out);
Etcdserverpb__MemberPromoteRequest *etcdserverpb__member_promote_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member_promote_request__free_unpacked(Etcdserverpb__MemberPromoteRequest *message, ProtobufCAllocator *allocator);

size_t etcdserverpb__member_promote_response__get_packed_size(const Etcdserverpb__MemberPromoteResponse *message);
size_t etcdserverpb__member_promote_response__pack(const Etcdserverpb__MemberPromoteResponse *message, uint8_t *out);
Etcdserverpb__MemberPromoteResponse *etcdserverpb__member_promote_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data);
void etcdserverpb__member_promote_response__free_unpacked(Etcdserverpb__MemberPromoteResponse *message, ProtobufCAllocator *allocator);

PROTOBUF_C__END_DECLS

#endif /* CLUSTER_PB_C_H */
