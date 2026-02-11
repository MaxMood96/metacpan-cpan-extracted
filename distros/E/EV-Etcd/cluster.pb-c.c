/*
 * cluster.pb-c.c - Protocol Buffers for etcd v3 Cluster service
 *
 * Generated manually based on etcd/api/etcdserverpb/rpc.proto
 */

/* Do not generate deprecated warnings for self */
#ifndef PROTOBUF_C__NO_DEPRECATED
#define PROTOBUF_C__NO_DEPRECATED
#endif

#include "cluster.pb-c.h"

/* Member */
void etcdserverpb__member__init(Etcdserverpb__Member *message)
{
    static const Etcdserverpb__Member init_value = ETCDSERVERPB__MEMBER__INIT;
    *message = init_value;
}

size_t etcdserverpb__member__get_packed_size(const Etcdserverpb__Member *message)
{
    assert(message->base.descriptor == &etcdserverpb__member__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member__pack(const Etcdserverpb__Member *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__Member *etcdserverpb__member__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__Member *)
        protobuf_c_message_unpack(&etcdserverpb__member__descriptor, allocator, len, data);
}

void etcdserverpb__member__free_unpacked(Etcdserverpb__Member *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* MemberAddRequest */
void etcdserverpb__member_add_request__init(Etcdserverpb__MemberAddRequest *message)
{
    static const Etcdserverpb__MemberAddRequest init_value = ETCDSERVERPB__MEMBER_ADD_REQUEST__INIT;
    *message = init_value;
}

size_t etcdserverpb__member_add_request__get_packed_size(const Etcdserverpb__MemberAddRequest *message)
{
    assert(message->base.descriptor == &etcdserverpb__member_add_request__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member_add_request__pack(const Etcdserverpb__MemberAddRequest *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member_add_request__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__MemberAddRequest *etcdserverpb__member_add_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__MemberAddRequest *)
        protobuf_c_message_unpack(&etcdserverpb__member_add_request__descriptor, allocator, len, data);
}

void etcdserverpb__member_add_request__free_unpacked(Etcdserverpb__MemberAddRequest *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member_add_request__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* MemberAddResponse */
void etcdserverpb__member_add_response__init(Etcdserverpb__MemberAddResponse *message)
{
    static const Etcdserverpb__MemberAddResponse init_value = ETCDSERVERPB__MEMBER_ADD_RESPONSE__INIT;
    *message = init_value;
}

size_t etcdserverpb__member_add_response__get_packed_size(const Etcdserverpb__MemberAddResponse *message)
{
    assert(message->base.descriptor == &etcdserverpb__member_add_response__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member_add_response__pack(const Etcdserverpb__MemberAddResponse *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member_add_response__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__MemberAddResponse *etcdserverpb__member_add_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__MemberAddResponse *)
        protobuf_c_message_unpack(&etcdserverpb__member_add_response__descriptor, allocator, len, data);
}

void etcdserverpb__member_add_response__free_unpacked(Etcdserverpb__MemberAddResponse *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member_add_response__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* MemberRemoveRequest */
void etcdserverpb__member_remove_request__init(Etcdserverpb__MemberRemoveRequest *message)
{
    static const Etcdserverpb__MemberRemoveRequest init_value = ETCDSERVERPB__MEMBER_REMOVE_REQUEST__INIT;
    *message = init_value;
}

size_t etcdserverpb__member_remove_request__get_packed_size(const Etcdserverpb__MemberRemoveRequest *message)
{
    assert(message->base.descriptor == &etcdserverpb__member_remove_request__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member_remove_request__pack(const Etcdserverpb__MemberRemoveRequest *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member_remove_request__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__MemberRemoveRequest *etcdserverpb__member_remove_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__MemberRemoveRequest *)
        protobuf_c_message_unpack(&etcdserverpb__member_remove_request__descriptor, allocator, len, data);
}

void etcdserverpb__member_remove_request__free_unpacked(Etcdserverpb__MemberRemoveRequest *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member_remove_request__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* MemberRemoveResponse */
void etcdserverpb__member_remove_response__init(Etcdserverpb__MemberRemoveResponse *message)
{
    static const Etcdserverpb__MemberRemoveResponse init_value = ETCDSERVERPB__MEMBER_REMOVE_RESPONSE__INIT;
    *message = init_value;
}

size_t etcdserverpb__member_remove_response__get_packed_size(const Etcdserverpb__MemberRemoveResponse *message)
{
    assert(message->base.descriptor == &etcdserverpb__member_remove_response__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member_remove_response__pack(const Etcdserverpb__MemberRemoveResponse *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member_remove_response__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__MemberRemoveResponse *etcdserverpb__member_remove_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__MemberRemoveResponse *)
        protobuf_c_message_unpack(&etcdserverpb__member_remove_response__descriptor, allocator, len, data);
}

void etcdserverpb__member_remove_response__free_unpacked(Etcdserverpb__MemberRemoveResponse *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member_remove_response__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* MemberUpdateRequest */
void etcdserverpb__member_update_request__init(Etcdserverpb__MemberUpdateRequest *message)
{
    static const Etcdserverpb__MemberUpdateRequest init_value = ETCDSERVERPB__MEMBER_UPDATE_REQUEST__INIT;
    *message = init_value;
}

size_t etcdserverpb__member_update_request__get_packed_size(const Etcdserverpb__MemberUpdateRequest *message)
{
    assert(message->base.descriptor == &etcdserverpb__member_update_request__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member_update_request__pack(const Etcdserverpb__MemberUpdateRequest *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member_update_request__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__MemberUpdateRequest *etcdserverpb__member_update_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__MemberUpdateRequest *)
        protobuf_c_message_unpack(&etcdserverpb__member_update_request__descriptor, allocator, len, data);
}

void etcdserverpb__member_update_request__free_unpacked(Etcdserverpb__MemberUpdateRequest *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member_update_request__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* MemberUpdateResponse */
void etcdserverpb__member_update_response__init(Etcdserverpb__MemberUpdateResponse *message)
{
    static const Etcdserverpb__MemberUpdateResponse init_value = ETCDSERVERPB__MEMBER_UPDATE_RESPONSE__INIT;
    *message = init_value;
}

size_t etcdserverpb__member_update_response__get_packed_size(const Etcdserverpb__MemberUpdateResponse *message)
{
    assert(message->base.descriptor == &etcdserverpb__member_update_response__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member_update_response__pack(const Etcdserverpb__MemberUpdateResponse *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member_update_response__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__MemberUpdateResponse *etcdserverpb__member_update_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__MemberUpdateResponse *)
        protobuf_c_message_unpack(&etcdserverpb__member_update_response__descriptor, allocator, len, data);
}

void etcdserverpb__member_update_response__free_unpacked(Etcdserverpb__MemberUpdateResponse *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member_update_response__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* MemberListRequest */
void etcdserverpb__member_list_request__init(Etcdserverpb__MemberListRequest *message)
{
    static const Etcdserverpb__MemberListRequest init_value = ETCDSERVERPB__MEMBER_LIST_REQUEST__INIT;
    *message = init_value;
}

size_t etcdserverpb__member_list_request__get_packed_size(const Etcdserverpb__MemberListRequest *message)
{
    assert(message->base.descriptor == &etcdserverpb__member_list_request__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member_list_request__pack(const Etcdserverpb__MemberListRequest *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member_list_request__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__MemberListRequest *etcdserverpb__member_list_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__MemberListRequest *)
        protobuf_c_message_unpack(&etcdserverpb__member_list_request__descriptor, allocator, len, data);
}

void etcdserverpb__member_list_request__free_unpacked(Etcdserverpb__MemberListRequest *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member_list_request__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* MemberListResponse */
void etcdserverpb__member_list_response__init(Etcdserverpb__MemberListResponse *message)
{
    static const Etcdserverpb__MemberListResponse init_value = ETCDSERVERPB__MEMBER_LIST_RESPONSE__INIT;
    *message = init_value;
}

size_t etcdserverpb__member_list_response__get_packed_size(const Etcdserverpb__MemberListResponse *message)
{
    assert(message->base.descriptor == &etcdserverpb__member_list_response__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member_list_response__pack(const Etcdserverpb__MemberListResponse *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member_list_response__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__MemberListResponse *etcdserverpb__member_list_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__MemberListResponse *)
        protobuf_c_message_unpack(&etcdserverpb__member_list_response__descriptor, allocator, len, data);
}

void etcdserverpb__member_list_response__free_unpacked(Etcdserverpb__MemberListResponse *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member_list_response__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* MemberPromoteRequest */
void etcdserverpb__member_promote_request__init(Etcdserverpb__MemberPromoteRequest *message)
{
    static const Etcdserverpb__MemberPromoteRequest init_value = ETCDSERVERPB__MEMBER_PROMOTE_REQUEST__INIT;
    *message = init_value;
}

size_t etcdserverpb__member_promote_request__get_packed_size(const Etcdserverpb__MemberPromoteRequest *message)
{
    assert(message->base.descriptor == &etcdserverpb__member_promote_request__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member_promote_request__pack(const Etcdserverpb__MemberPromoteRequest *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member_promote_request__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__MemberPromoteRequest *etcdserverpb__member_promote_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__MemberPromoteRequest *)
        protobuf_c_message_unpack(&etcdserverpb__member_promote_request__descriptor, allocator, len, data);
}

void etcdserverpb__member_promote_request__free_unpacked(Etcdserverpb__MemberPromoteRequest *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member_promote_request__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* MemberPromoteResponse */
void etcdserverpb__member_promote_response__init(Etcdserverpb__MemberPromoteResponse *message)
{
    static const Etcdserverpb__MemberPromoteResponse init_value = ETCDSERVERPB__MEMBER_PROMOTE_RESPONSE__INIT;
    *message = init_value;
}

size_t etcdserverpb__member_promote_response__get_packed_size(const Etcdserverpb__MemberPromoteResponse *message)
{
    assert(message->base.descriptor == &etcdserverpb__member_promote_response__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t etcdserverpb__member_promote_response__pack(const Etcdserverpb__MemberPromoteResponse *message, uint8_t *out)
{
    assert(message->base.descriptor == &etcdserverpb__member_promote_response__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

Etcdserverpb__MemberPromoteResponse *etcdserverpb__member_promote_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (Etcdserverpb__MemberPromoteResponse *)
        protobuf_c_message_unpack(&etcdserverpb__member_promote_response__descriptor, allocator, len, data);
}

void etcdserverpb__member_promote_response__free_unpacked(Etcdserverpb__MemberPromoteResponse *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &etcdserverpb__member_promote_response__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* Field Descriptors */

/* Member: ID(1), name(2), peerURLs(3), clientURLs(4), isLearner(5) */
static const ProtobufCFieldDescriptor etcdserverpb__member__field_descriptors[5] =
{
    {
        "ID",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_UINT64,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__Member, id),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "name",
        2,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_STRING,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__Member, name),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "peerURLs",
        3,
        PROTOBUF_C_LABEL_REPEATED,
        PROTOBUF_C_TYPE_STRING,
        offsetof(Etcdserverpb__Member, n_peer_urls),
        offsetof(Etcdserverpb__Member, peer_urls),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "clientURLs",
        4,
        PROTOBUF_C_LABEL_REPEATED,
        PROTOBUF_C_TYPE_STRING,
        offsetof(Etcdserverpb__Member, n_client_urls),
        offsetof(Etcdserverpb__Member, client_urls),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "isLearner",
        5,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_BOOL,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__Member, is_learner),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member__field_indices_by_name[] = {
    0,   /* field[0] = ID */
    3,   /* field[3] = clientURLs */
    4,   /* field[4] = isLearner */
    1,   /* field[1] = name */
    2,   /* field[2] = peerURLs */
};
static const ProtobufCIntRange etcdserverpb__member__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 5 }
};
const ProtobufCMessageDescriptor etcdserverpb__member__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.Member",
    "Member",
    "Etcdserverpb__Member",
    "etcdserverpb",
    sizeof(Etcdserverpb__Member),
    5,
    etcdserverpb__member__field_descriptors,
    etcdserverpb__member__field_indices_by_name,
    1,  etcdserverpb__member__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* MemberAddRequest: peerURLs(1), isLearner(2) */
static const ProtobufCFieldDescriptor etcdserverpb__member_add_request__field_descriptors[2] =
{
    {
        "peerURLs",
        1,
        PROTOBUF_C_LABEL_REPEATED,
        PROTOBUF_C_TYPE_STRING,
        offsetof(Etcdserverpb__MemberAddRequest, n_peer_urls),
        offsetof(Etcdserverpb__MemberAddRequest, peer_urls),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "isLearner",
        2,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_BOOL,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberAddRequest, is_learner),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member_add_request__field_indices_by_name[] = {
    1,   /* field[1] = isLearner */
    0,   /* field[0] = peerURLs */
};
static const ProtobufCIntRange etcdserverpb__member_add_request__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 2 }
};
const ProtobufCMessageDescriptor etcdserverpb__member_add_request__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.MemberAddRequest",
    "MemberAddRequest",
    "Etcdserverpb__MemberAddRequest",
    "etcdserverpb",
    sizeof(Etcdserverpb__MemberAddRequest),
    2,
    etcdserverpb__member_add_request__field_descriptors,
    etcdserverpb__member_add_request__field_indices_by_name,
    1,  etcdserverpb__member_add_request__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member_add_request__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* MemberAddResponse: header(1), member(2), members(3) */
static const ProtobufCFieldDescriptor etcdserverpb__member_add_response__field_descriptors[3] =
{
    {
        "header",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberAddResponse, header),
        &etcdserverpb__response_header__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "member",
        2,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberAddResponse, member),
        &etcdserverpb__member__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "members",
        3,
        PROTOBUF_C_LABEL_REPEATED,
        PROTOBUF_C_TYPE_MESSAGE,
        offsetof(Etcdserverpb__MemberAddResponse, n_members),
        offsetof(Etcdserverpb__MemberAddResponse, members),
        &etcdserverpb__member__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member_add_response__field_indices_by_name[] = {
    0,   /* field[0] = header */
    1,   /* field[1] = member */
    2,   /* field[2] = members */
};
static const ProtobufCIntRange etcdserverpb__member_add_response__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 3 }
};
const ProtobufCMessageDescriptor etcdserverpb__member_add_response__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.MemberAddResponse",
    "MemberAddResponse",
    "Etcdserverpb__MemberAddResponse",
    "etcdserverpb",
    sizeof(Etcdserverpb__MemberAddResponse),
    3,
    etcdserverpb__member_add_response__field_descriptors,
    etcdserverpb__member_add_response__field_indices_by_name,
    1,  etcdserverpb__member_add_response__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member_add_response__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* MemberRemoveRequest: ID(1) */
static const ProtobufCFieldDescriptor etcdserverpb__member_remove_request__field_descriptors[1] =
{
    {
        "ID",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_UINT64,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberRemoveRequest, id),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member_remove_request__field_indices_by_name[] = {
    0,   /* field[0] = ID */
};
static const ProtobufCIntRange etcdserverpb__member_remove_request__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 1 }
};
const ProtobufCMessageDescriptor etcdserverpb__member_remove_request__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.MemberRemoveRequest",
    "MemberRemoveRequest",
    "Etcdserverpb__MemberRemoveRequest",
    "etcdserverpb",
    sizeof(Etcdserverpb__MemberRemoveRequest),
    1,
    etcdserverpb__member_remove_request__field_descriptors,
    etcdserverpb__member_remove_request__field_indices_by_name,
    1,  etcdserverpb__member_remove_request__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member_remove_request__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* MemberRemoveResponse: header(1), members(2) */
static const ProtobufCFieldDescriptor etcdserverpb__member_remove_response__field_descriptors[2] =
{
    {
        "header",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberRemoveResponse, header),
        &etcdserverpb__response_header__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "members",
        2,
        PROTOBUF_C_LABEL_REPEATED,
        PROTOBUF_C_TYPE_MESSAGE,
        offsetof(Etcdserverpb__MemberRemoveResponse, n_members),
        offsetof(Etcdserverpb__MemberRemoveResponse, members),
        &etcdserverpb__member__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member_remove_response__field_indices_by_name[] = {
    0,   /* field[0] = header */
    1,   /* field[1] = members */
};
static const ProtobufCIntRange etcdserverpb__member_remove_response__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 2 }
};
const ProtobufCMessageDescriptor etcdserverpb__member_remove_response__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.MemberRemoveResponse",
    "MemberRemoveResponse",
    "Etcdserverpb__MemberRemoveResponse",
    "etcdserverpb",
    sizeof(Etcdserverpb__MemberRemoveResponse),
    2,
    etcdserverpb__member_remove_response__field_descriptors,
    etcdserverpb__member_remove_response__field_indices_by_name,
    1,  etcdserverpb__member_remove_response__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member_remove_response__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* MemberUpdateRequest: ID(1), peerURLs(2) */
static const ProtobufCFieldDescriptor etcdserverpb__member_update_request__field_descriptors[2] =
{
    {
        "ID",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_UINT64,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberUpdateRequest, id),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "peerURLs",
        2,
        PROTOBUF_C_LABEL_REPEATED,
        PROTOBUF_C_TYPE_STRING,
        offsetof(Etcdserverpb__MemberUpdateRequest, n_peer_urls),
        offsetof(Etcdserverpb__MemberUpdateRequest, peer_urls),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member_update_request__field_indices_by_name[] = {
    0,   /* field[0] = ID */
    1,   /* field[1] = peerURLs */
};
static const ProtobufCIntRange etcdserverpb__member_update_request__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 2 }
};
const ProtobufCMessageDescriptor etcdserverpb__member_update_request__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.MemberUpdateRequest",
    "MemberUpdateRequest",
    "Etcdserverpb__MemberUpdateRequest",
    "etcdserverpb",
    sizeof(Etcdserverpb__MemberUpdateRequest),
    2,
    etcdserverpb__member_update_request__field_descriptors,
    etcdserverpb__member_update_request__field_indices_by_name,
    1,  etcdserverpb__member_update_request__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member_update_request__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* MemberUpdateResponse: header(1), members(2) */
static const ProtobufCFieldDescriptor etcdserverpb__member_update_response__field_descriptors[2] =
{
    {
        "header",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberUpdateResponse, header),
        &etcdserverpb__response_header__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "members",
        2,
        PROTOBUF_C_LABEL_REPEATED,
        PROTOBUF_C_TYPE_MESSAGE,
        offsetof(Etcdserverpb__MemberUpdateResponse, n_members),
        offsetof(Etcdserverpb__MemberUpdateResponse, members),
        &etcdserverpb__member__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member_update_response__field_indices_by_name[] = {
    0,   /* field[0] = header */
    1,   /* field[1] = members */
};
static const ProtobufCIntRange etcdserverpb__member_update_response__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 2 }
};
const ProtobufCMessageDescriptor etcdserverpb__member_update_response__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.MemberUpdateResponse",
    "MemberUpdateResponse",
    "Etcdserverpb__MemberUpdateResponse",
    "etcdserverpb",
    sizeof(Etcdserverpb__MemberUpdateResponse),
    2,
    etcdserverpb__member_update_response__field_descriptors,
    etcdserverpb__member_update_response__field_indices_by_name,
    1,  etcdserverpb__member_update_response__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member_update_response__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* MemberListRequest: linearizable(1) */
static const ProtobufCFieldDescriptor etcdserverpb__member_list_request__field_descriptors[1] =
{
    {
        "linearizable",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_BOOL,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberListRequest, linearizable),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member_list_request__field_indices_by_name[] = {
    0,   /* field[0] = linearizable */
};
static const ProtobufCIntRange etcdserverpb__member_list_request__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 1 }
};
const ProtobufCMessageDescriptor etcdserverpb__member_list_request__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.MemberListRequest",
    "MemberListRequest",
    "Etcdserverpb__MemberListRequest",
    "etcdserverpb",
    sizeof(Etcdserverpb__MemberListRequest),
    1,
    etcdserverpb__member_list_request__field_descriptors,
    etcdserverpb__member_list_request__field_indices_by_name,
    1,  etcdserverpb__member_list_request__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member_list_request__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* MemberListResponse: header(1), members(2) */
static const ProtobufCFieldDescriptor etcdserverpb__member_list_response__field_descriptors[2] =
{
    {
        "header",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberListResponse, header),
        &etcdserverpb__response_header__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "members",
        2,
        PROTOBUF_C_LABEL_REPEATED,
        PROTOBUF_C_TYPE_MESSAGE,
        offsetof(Etcdserverpb__MemberListResponse, n_members),
        offsetof(Etcdserverpb__MemberListResponse, members),
        &etcdserverpb__member__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member_list_response__field_indices_by_name[] = {
    0,   /* field[0] = header */
    1,   /* field[1] = members */
};
static const ProtobufCIntRange etcdserverpb__member_list_response__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 2 }
};
const ProtobufCMessageDescriptor etcdserverpb__member_list_response__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.MemberListResponse",
    "MemberListResponse",
    "Etcdserverpb__MemberListResponse",
    "etcdserverpb",
    sizeof(Etcdserverpb__MemberListResponse),
    2,
    etcdserverpb__member_list_response__field_descriptors,
    etcdserverpb__member_list_response__field_indices_by_name,
    1,  etcdserverpb__member_list_response__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member_list_response__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* MemberPromoteRequest: ID(1) */
static const ProtobufCFieldDescriptor etcdserverpb__member_promote_request__field_descriptors[1] =
{
    {
        "ID",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_UINT64,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberPromoteRequest, id),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member_promote_request__field_indices_by_name[] = {
    0,   /* field[0] = ID */
};
static const ProtobufCIntRange etcdserverpb__member_promote_request__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 1 }
};
const ProtobufCMessageDescriptor etcdserverpb__member_promote_request__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.MemberPromoteRequest",
    "MemberPromoteRequest",
    "Etcdserverpb__MemberPromoteRequest",
    "etcdserverpb",
    sizeof(Etcdserverpb__MemberPromoteRequest),
    1,
    etcdserverpb__member_promote_request__field_descriptors,
    etcdserverpb__member_promote_request__field_indices_by_name,
    1,  etcdserverpb__member_promote_request__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member_promote_request__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* MemberPromoteResponse: header(1), members(2) */
static const ProtobufCFieldDescriptor etcdserverpb__member_promote_response__field_descriptors[2] =
{
    {
        "header",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(Etcdserverpb__MemberPromoteResponse, header),
        &etcdserverpb__response_header__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "members",
        2,
        PROTOBUF_C_LABEL_REPEATED,
        PROTOBUF_C_TYPE_MESSAGE,
        offsetof(Etcdserverpb__MemberPromoteResponse, n_members),
        offsetof(Etcdserverpb__MemberPromoteResponse, members),
        &etcdserverpb__member__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned etcdserverpb__member_promote_response__field_indices_by_name[] = {
    0,   /* field[0] = header */
    1,   /* field[1] = members */
};
static const ProtobufCIntRange etcdserverpb__member_promote_response__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 2 }
};
const ProtobufCMessageDescriptor etcdserverpb__member_promote_response__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "etcdserverpb.MemberPromoteResponse",
    "MemberPromoteResponse",
    "Etcdserverpb__MemberPromoteResponse",
    "etcdserverpb",
    sizeof(Etcdserverpb__MemberPromoteResponse),
    2,
    etcdserverpb__member_promote_response__field_descriptors,
    etcdserverpb__member_promote_response__field_indices_by_name,
    1,  etcdserverpb__member_promote_response__number_ranges,
    (ProtobufCMessageInit) etcdserverpb__member_promote_response__init,
    NULL,NULL,NULL    /* reserved[123] */
};
