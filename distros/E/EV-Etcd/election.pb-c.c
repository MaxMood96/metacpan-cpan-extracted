/*
 * election.pb-c.c - Protocol Buffers for etcd v3 Election service
 *
 * Generated manually based on etcd/api/v3election/v3electionpb/v3election.proto
 */

/* Do not generate deprecated warnings for self */
#ifndef PROTOBUF_C__NO_DEPRECATED
#define PROTOBUF_C__NO_DEPRECATED
#endif

#include "election.pb-c.h"

/* LeaderKey */
void v3electionpb__leader_key__init(V3electionpb__LeaderKey *message)
{
    static const V3electionpb__LeaderKey init_value = V3ELECTIONPB__LEADER_KEY__INIT;
    *message = init_value;
}

size_t v3electionpb__leader_key__get_packed_size(const V3electionpb__LeaderKey *message)
{
    assert(message->base.descriptor == &v3electionpb__leader_key__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t v3electionpb__leader_key__pack(const V3electionpb__LeaderKey *message, uint8_t *out)
{
    assert(message->base.descriptor == &v3electionpb__leader_key__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

size_t v3electionpb__leader_key__pack_to_buffer(const V3electionpb__LeaderKey *message, ProtobufCBuffer *buffer)
{
    assert(message->base.descriptor == &v3electionpb__leader_key__descriptor);
    return protobuf_c_message_pack_to_buffer((const ProtobufCMessage *)message, buffer);
}

V3electionpb__LeaderKey *v3electionpb__leader_key__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (V3electionpb__LeaderKey *)
        protobuf_c_message_unpack(&v3electionpb__leader_key__descriptor, allocator, len, data);
}

void v3electionpb__leader_key__free_unpacked(V3electionpb__LeaderKey *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &v3electionpb__leader_key__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* CampaignRequest */
void v3electionpb__campaign_request__init(V3electionpb__CampaignRequest *message)
{
    static const V3electionpb__CampaignRequest init_value = V3ELECTIONPB__CAMPAIGN_REQUEST__INIT;
    *message = init_value;
}

size_t v3electionpb__campaign_request__get_packed_size(const V3electionpb__CampaignRequest *message)
{
    assert(message->base.descriptor == &v3electionpb__campaign_request__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t v3electionpb__campaign_request__pack(const V3electionpb__CampaignRequest *message, uint8_t *out)
{
    assert(message->base.descriptor == &v3electionpb__campaign_request__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

size_t v3electionpb__campaign_request__pack_to_buffer(const V3electionpb__CampaignRequest *message, ProtobufCBuffer *buffer)
{
    assert(message->base.descriptor == &v3electionpb__campaign_request__descriptor);
    return protobuf_c_message_pack_to_buffer((const ProtobufCMessage *)message, buffer);
}

V3electionpb__CampaignRequest *v3electionpb__campaign_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (V3electionpb__CampaignRequest *)
        protobuf_c_message_unpack(&v3electionpb__campaign_request__descriptor, allocator, len, data);
}

void v3electionpb__campaign_request__free_unpacked(V3electionpb__CampaignRequest *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &v3electionpb__campaign_request__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* CampaignResponse */
void v3electionpb__campaign_response__init(V3electionpb__CampaignResponse *message)
{
    static const V3electionpb__CampaignResponse init_value = V3ELECTIONPB__CAMPAIGN_RESPONSE__INIT;
    *message = init_value;
}

size_t v3electionpb__campaign_response__get_packed_size(const V3electionpb__CampaignResponse *message)
{
    assert(message->base.descriptor == &v3electionpb__campaign_response__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t v3electionpb__campaign_response__pack(const V3electionpb__CampaignResponse *message, uint8_t *out)
{
    assert(message->base.descriptor == &v3electionpb__campaign_response__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

size_t v3electionpb__campaign_response__pack_to_buffer(const V3electionpb__CampaignResponse *message, ProtobufCBuffer *buffer)
{
    assert(message->base.descriptor == &v3electionpb__campaign_response__descriptor);
    return protobuf_c_message_pack_to_buffer((const ProtobufCMessage *)message, buffer);
}

V3electionpb__CampaignResponse *v3electionpb__campaign_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (V3electionpb__CampaignResponse *)
        protobuf_c_message_unpack(&v3electionpb__campaign_response__descriptor, allocator, len, data);
}

void v3electionpb__campaign_response__free_unpacked(V3electionpb__CampaignResponse *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &v3electionpb__campaign_response__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* LeaderRequest */
void v3electionpb__leader_request__init(V3electionpb__LeaderRequest *message)
{
    static const V3electionpb__LeaderRequest init_value = V3ELECTIONPB__LEADER_REQUEST__INIT;
    *message = init_value;
}

size_t v3electionpb__leader_request__get_packed_size(const V3electionpb__LeaderRequest *message)
{
    assert(message->base.descriptor == &v3electionpb__leader_request__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t v3electionpb__leader_request__pack(const V3electionpb__LeaderRequest *message, uint8_t *out)
{
    assert(message->base.descriptor == &v3electionpb__leader_request__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

size_t v3electionpb__leader_request__pack_to_buffer(const V3electionpb__LeaderRequest *message, ProtobufCBuffer *buffer)
{
    assert(message->base.descriptor == &v3electionpb__leader_request__descriptor);
    return protobuf_c_message_pack_to_buffer((const ProtobufCMessage *)message, buffer);
}

V3electionpb__LeaderRequest *v3electionpb__leader_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (V3electionpb__LeaderRequest *)
        protobuf_c_message_unpack(&v3electionpb__leader_request__descriptor, allocator, len, data);
}

void v3electionpb__leader_request__free_unpacked(V3electionpb__LeaderRequest *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &v3electionpb__leader_request__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* LeaderResponse */
void v3electionpb__leader_response__init(V3electionpb__LeaderResponse *message)
{
    static const V3electionpb__LeaderResponse init_value = V3ELECTIONPB__LEADER_RESPONSE__INIT;
    *message = init_value;
}

size_t v3electionpb__leader_response__get_packed_size(const V3electionpb__LeaderResponse *message)
{
    assert(message->base.descriptor == &v3electionpb__leader_response__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t v3electionpb__leader_response__pack(const V3electionpb__LeaderResponse *message, uint8_t *out)
{
    assert(message->base.descriptor == &v3electionpb__leader_response__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

size_t v3electionpb__leader_response__pack_to_buffer(const V3electionpb__LeaderResponse *message, ProtobufCBuffer *buffer)
{
    assert(message->base.descriptor == &v3electionpb__leader_response__descriptor);
    return protobuf_c_message_pack_to_buffer((const ProtobufCMessage *)message, buffer);
}

V3electionpb__LeaderResponse *v3electionpb__leader_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (V3electionpb__LeaderResponse *)
        protobuf_c_message_unpack(&v3electionpb__leader_response__descriptor, allocator, len, data);
}

void v3electionpb__leader_response__free_unpacked(V3electionpb__LeaderResponse *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &v3electionpb__leader_response__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* ResignRequest */
void v3electionpb__resign_request__init(V3electionpb__ResignRequest *message)
{
    static const V3electionpb__ResignRequest init_value = V3ELECTIONPB__RESIGN_REQUEST__INIT;
    *message = init_value;
}

size_t v3electionpb__resign_request__get_packed_size(const V3electionpb__ResignRequest *message)
{
    assert(message->base.descriptor == &v3electionpb__resign_request__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t v3electionpb__resign_request__pack(const V3electionpb__ResignRequest *message, uint8_t *out)
{
    assert(message->base.descriptor == &v3electionpb__resign_request__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

size_t v3electionpb__resign_request__pack_to_buffer(const V3electionpb__ResignRequest *message, ProtobufCBuffer *buffer)
{
    assert(message->base.descriptor == &v3electionpb__resign_request__descriptor);
    return protobuf_c_message_pack_to_buffer((const ProtobufCMessage *)message, buffer);
}

V3electionpb__ResignRequest *v3electionpb__resign_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (V3electionpb__ResignRequest *)
        protobuf_c_message_unpack(&v3electionpb__resign_request__descriptor, allocator, len, data);
}

void v3electionpb__resign_request__free_unpacked(V3electionpb__ResignRequest *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &v3electionpb__resign_request__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* ResignResponse */
void v3electionpb__resign_response__init(V3electionpb__ResignResponse *message)
{
    static const V3electionpb__ResignResponse init_value = V3ELECTIONPB__RESIGN_RESPONSE__INIT;
    *message = init_value;
}

size_t v3electionpb__resign_response__get_packed_size(const V3electionpb__ResignResponse *message)
{
    assert(message->base.descriptor == &v3electionpb__resign_response__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t v3electionpb__resign_response__pack(const V3electionpb__ResignResponse *message, uint8_t *out)
{
    assert(message->base.descriptor == &v3electionpb__resign_response__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

size_t v3electionpb__resign_response__pack_to_buffer(const V3electionpb__ResignResponse *message, ProtobufCBuffer *buffer)
{
    assert(message->base.descriptor == &v3electionpb__resign_response__descriptor);
    return protobuf_c_message_pack_to_buffer((const ProtobufCMessage *)message, buffer);
}

V3electionpb__ResignResponse *v3electionpb__resign_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (V3electionpb__ResignResponse *)
        protobuf_c_message_unpack(&v3electionpb__resign_response__descriptor, allocator, len, data);
}

void v3electionpb__resign_response__free_unpacked(V3electionpb__ResignResponse *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &v3electionpb__resign_response__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* ProclaimRequest */
void v3electionpb__proclaim_request__init(V3electionpb__ProclaimRequest *message)
{
    static const V3electionpb__ProclaimRequest init_value = V3ELECTIONPB__PROCLAIM_REQUEST__INIT;
    *message = init_value;
}

size_t v3electionpb__proclaim_request__get_packed_size(const V3electionpb__ProclaimRequest *message)
{
    assert(message->base.descriptor == &v3electionpb__proclaim_request__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t v3electionpb__proclaim_request__pack(const V3electionpb__ProclaimRequest *message, uint8_t *out)
{
    assert(message->base.descriptor == &v3electionpb__proclaim_request__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

size_t v3electionpb__proclaim_request__pack_to_buffer(const V3electionpb__ProclaimRequest *message, ProtobufCBuffer *buffer)
{
    assert(message->base.descriptor == &v3electionpb__proclaim_request__descriptor);
    return protobuf_c_message_pack_to_buffer((const ProtobufCMessage *)message, buffer);
}

V3electionpb__ProclaimRequest *v3electionpb__proclaim_request__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (V3electionpb__ProclaimRequest *)
        protobuf_c_message_unpack(&v3electionpb__proclaim_request__descriptor, allocator, len, data);
}

void v3electionpb__proclaim_request__free_unpacked(V3electionpb__ProclaimRequest *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &v3electionpb__proclaim_request__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* ProclaimResponse */
void v3electionpb__proclaim_response__init(V3electionpb__ProclaimResponse *message)
{
    static const V3electionpb__ProclaimResponse init_value = V3ELECTIONPB__PROCLAIM_RESPONSE__INIT;
    *message = init_value;
}

size_t v3electionpb__proclaim_response__get_packed_size(const V3electionpb__ProclaimResponse *message)
{
    assert(message->base.descriptor == &v3electionpb__proclaim_response__descriptor);
    return protobuf_c_message_get_packed_size((const ProtobufCMessage *)(message));
}

size_t v3electionpb__proclaim_response__pack(const V3electionpb__ProclaimResponse *message, uint8_t *out)
{
    assert(message->base.descriptor == &v3electionpb__proclaim_response__descriptor);
    return protobuf_c_message_pack((const ProtobufCMessage *)message, out);
}

size_t v3electionpb__proclaim_response__pack_to_buffer(const V3electionpb__ProclaimResponse *message, ProtobufCBuffer *buffer)
{
    assert(message->base.descriptor == &v3electionpb__proclaim_response__descriptor);
    return protobuf_c_message_pack_to_buffer((const ProtobufCMessage *)message, buffer);
}

V3electionpb__ProclaimResponse *v3electionpb__proclaim_response__unpack(ProtobufCAllocator *allocator, size_t len, const uint8_t *data)
{
    return (V3electionpb__ProclaimResponse *)
        protobuf_c_message_unpack(&v3electionpb__proclaim_response__descriptor, allocator, len, data);
}

void v3electionpb__proclaim_response__free_unpacked(V3electionpb__ProclaimResponse *message, ProtobufCAllocator *allocator)
{
    if (!message)
        return;
    assert(message->base.descriptor == &v3electionpb__proclaim_response__descriptor);
    protobuf_c_message_free_unpacked((ProtobufCMessage *)message, allocator);
}

/* Field Descriptors */

/* LeaderKey: name(1), key(2), rev(3), lease(4) */
static const ProtobufCFieldDescriptor v3electionpb__leader_key__field_descriptors[4] =
{
    {
        "name",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_BYTES,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__LeaderKey, name),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "key",
        2,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_BYTES,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__LeaderKey, key),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "rev",
        3,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_INT64,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__LeaderKey, rev),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "lease",
        4,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_INT64,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__LeaderKey, lease),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned v3electionpb__leader_key__field_indices_by_name[] = {
    1,   /* field[1] = key */
    3,   /* field[3] = lease */
    0,   /* field[0] = name */
    2,   /* field[2] = rev */
};
static const ProtobufCIntRange v3electionpb__leader_key__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 4 }
};
const ProtobufCMessageDescriptor v3electionpb__leader_key__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "v3electionpb.LeaderKey",
    "LeaderKey",
    "V3electionpb__LeaderKey",
    "v3electionpb",
    sizeof(V3electionpb__LeaderKey),
    4,
    v3electionpb__leader_key__field_descriptors,
    v3electionpb__leader_key__field_indices_by_name,
    1,  v3electionpb__leader_key__number_ranges,
    (ProtobufCMessageInit) v3electionpb__leader_key__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* CampaignRequest: name(1), lease(2), value(3) */
static const ProtobufCFieldDescriptor v3electionpb__campaign_request__field_descriptors[3] =
{
    {
        "name",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_BYTES,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__CampaignRequest, name),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "lease",
        2,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_INT64,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__CampaignRequest, lease),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "value",
        3,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_BYTES,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__CampaignRequest, value),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned v3electionpb__campaign_request__field_indices_by_name[] = {
    1,   /* field[1] = lease */
    0,   /* field[0] = name */
    2,   /* field[2] = value */
};
static const ProtobufCIntRange v3electionpb__campaign_request__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 3 }
};
const ProtobufCMessageDescriptor v3electionpb__campaign_request__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "v3electionpb.CampaignRequest",
    "CampaignRequest",
    "V3electionpb__CampaignRequest",
    "v3electionpb",
    sizeof(V3electionpb__CampaignRequest),
    3,
    v3electionpb__campaign_request__field_descriptors,
    v3electionpb__campaign_request__field_indices_by_name,
    1,  v3electionpb__campaign_request__number_ranges,
    (ProtobufCMessageInit) v3electionpb__campaign_request__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* CampaignResponse: header(1), leader(2) */
static const ProtobufCFieldDescriptor v3electionpb__campaign_response__field_descriptors[2] =
{
    {
        "header",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__CampaignResponse, header),
        &etcdserverpb__response_header__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "leader",
        2,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__CampaignResponse, leader),
        &v3electionpb__leader_key__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned v3electionpb__campaign_response__field_indices_by_name[] = {
    0,   /* field[0] = header */
    1,   /* field[1] = leader */
};
static const ProtobufCIntRange v3electionpb__campaign_response__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 2 }
};
const ProtobufCMessageDescriptor v3electionpb__campaign_response__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "v3electionpb.CampaignResponse",
    "CampaignResponse",
    "V3electionpb__CampaignResponse",
    "v3electionpb",
    sizeof(V3electionpb__CampaignResponse),
    2,
    v3electionpb__campaign_response__field_descriptors,
    v3electionpb__campaign_response__field_indices_by_name,
    1,  v3electionpb__campaign_response__number_ranges,
    (ProtobufCMessageInit) v3electionpb__campaign_response__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* LeaderRequest: name(1) */
static const ProtobufCFieldDescriptor v3electionpb__leader_request__field_descriptors[1] =
{
    {
        "name",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_BYTES,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__LeaderRequest, name),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned v3electionpb__leader_request__field_indices_by_name[] = {
    0,   /* field[0] = name */
};
static const ProtobufCIntRange v3electionpb__leader_request__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 1 }
};
const ProtobufCMessageDescriptor v3electionpb__leader_request__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "v3electionpb.LeaderRequest",
    "LeaderRequest",
    "V3electionpb__LeaderRequest",
    "v3electionpb",
    sizeof(V3electionpb__LeaderRequest),
    1,
    v3electionpb__leader_request__field_descriptors,
    v3electionpb__leader_request__field_indices_by_name,
    1,  v3electionpb__leader_request__number_ranges,
    (ProtobufCMessageInit) v3electionpb__leader_request__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* LeaderResponse: header(1), kv(2) */
static const ProtobufCFieldDescriptor v3electionpb__leader_response__field_descriptors[2] =
{
    {
        "header",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__LeaderResponse, header),
        &etcdserverpb__response_header__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "kv",
        2,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__LeaderResponse, kv),
        &mvccpb__key_value__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned v3electionpb__leader_response__field_indices_by_name[] = {
    0,   /* field[0] = header */
    1,   /* field[1] = kv */
};
static const ProtobufCIntRange v3electionpb__leader_response__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 2 }
};
const ProtobufCMessageDescriptor v3electionpb__leader_response__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "v3electionpb.LeaderResponse",
    "LeaderResponse",
    "V3electionpb__LeaderResponse",
    "v3electionpb",
    sizeof(V3electionpb__LeaderResponse),
    2,
    v3electionpb__leader_response__field_descriptors,
    v3electionpb__leader_response__field_indices_by_name,
    1,  v3electionpb__leader_response__number_ranges,
    (ProtobufCMessageInit) v3electionpb__leader_response__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* ResignRequest: leader(1) */
static const ProtobufCFieldDescriptor v3electionpb__resign_request__field_descriptors[1] =
{
    {
        "leader",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__ResignRequest, leader),
        &v3electionpb__leader_key__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned v3electionpb__resign_request__field_indices_by_name[] = {
    0,   /* field[0] = leader */
};
static const ProtobufCIntRange v3electionpb__resign_request__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 1 }
};
const ProtobufCMessageDescriptor v3electionpb__resign_request__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "v3electionpb.ResignRequest",
    "ResignRequest",
    "V3electionpb__ResignRequest",
    "v3electionpb",
    sizeof(V3electionpb__ResignRequest),
    1,
    v3electionpb__resign_request__field_descriptors,
    v3electionpb__resign_request__field_indices_by_name,
    1,  v3electionpb__resign_request__number_ranges,
    (ProtobufCMessageInit) v3electionpb__resign_request__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* ResignResponse: header(1) */
static const ProtobufCFieldDescriptor v3electionpb__resign_response__field_descriptors[1] =
{
    {
        "header",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__ResignResponse, header),
        &etcdserverpb__response_header__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned v3electionpb__resign_response__field_indices_by_name[] = {
    0,   /* field[0] = header */
};
static const ProtobufCIntRange v3electionpb__resign_response__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 1 }
};
const ProtobufCMessageDescriptor v3electionpb__resign_response__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "v3electionpb.ResignResponse",
    "ResignResponse",
    "V3electionpb__ResignResponse",
    "v3electionpb",
    sizeof(V3electionpb__ResignResponse),
    1,
    v3electionpb__resign_response__field_descriptors,
    v3electionpb__resign_response__field_indices_by_name,
    1,  v3electionpb__resign_response__number_ranges,
    (ProtobufCMessageInit) v3electionpb__resign_response__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* ProclaimRequest: leader(1), value(2) */
static const ProtobufCFieldDescriptor v3electionpb__proclaim_request__field_descriptors[2] =
{
    {
        "leader",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__ProclaimRequest, leader),
        &v3electionpb__leader_key__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
    {
        "value",
        2,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_BYTES,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__ProclaimRequest, value),
        NULL,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned v3electionpb__proclaim_request__field_indices_by_name[] = {
    0,   /* field[0] = leader */
    1,   /* field[1] = value */
};
static const ProtobufCIntRange v3electionpb__proclaim_request__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 2 }
};
const ProtobufCMessageDescriptor v3electionpb__proclaim_request__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "v3electionpb.ProclaimRequest",
    "ProclaimRequest",
    "V3electionpb__ProclaimRequest",
    "v3electionpb",
    sizeof(V3electionpb__ProclaimRequest),
    2,
    v3electionpb__proclaim_request__field_descriptors,
    v3electionpb__proclaim_request__field_indices_by_name,
    1,  v3electionpb__proclaim_request__number_ranges,
    (ProtobufCMessageInit) v3electionpb__proclaim_request__init,
    NULL,NULL,NULL    /* reserved[123] */
};

/* ProclaimResponse: header(1) */
static const ProtobufCFieldDescriptor v3electionpb__proclaim_response__field_descriptors[1] =
{
    {
        "header",
        1,
        PROTOBUF_C_LABEL_NONE,
        PROTOBUF_C_TYPE_MESSAGE,
        0,   /* quantifier_offset */
        offsetof(V3electionpb__ProclaimResponse, header),
        &etcdserverpb__response_header__descriptor,
        NULL,
        0,             /* flags */
        0,NULL,NULL    /* reserved1,reserved2, etc */
    },
};
static const unsigned v3electionpb__proclaim_response__field_indices_by_name[] = {
    0,   /* field[0] = header */
};
static const ProtobufCIntRange v3electionpb__proclaim_response__number_ranges[1 + 1] =
{
    { 1, 0 },
    { 0, 1 }
};
const ProtobufCMessageDescriptor v3electionpb__proclaim_response__descriptor =
{
    PROTOBUF_C__MESSAGE_DESCRIPTOR_MAGIC,
    "v3electionpb.ProclaimResponse",
    "ProclaimResponse",
    "V3electionpb__ProclaimResponse",
    "v3electionpb",
    sizeof(V3electionpb__ProclaimResponse),
    1,
    v3electionpb__proclaim_response__field_descriptors,
    v3electionpb__proclaim_response__field_indices_by_name,
    1,  v3electionpb__proclaim_response__number_ranges,
    (ProtobufCMessageInit) v3electionpb__proclaim_response__init,
    NULL,NULL,NULL    /* reserved[123] */
};
