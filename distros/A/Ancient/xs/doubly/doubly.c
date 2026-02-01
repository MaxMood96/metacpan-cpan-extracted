/*
 * doubly.c - Thread-safe doubly linked list with SV registry
 *
 * Architecture following slot.c pattern:
 * - Dynamic SV-based node storage (no serialization)
 * - Index-based linking for thread safety (indices clone safely)
 * - Full API compatibility with Doubly module
 */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "doubly_compat.h"

/* ============================================
   Data Structures
   ============================================ */

/* Node storage - index-based linking for thread safety */
typedef struct DoublyNodeSlot {
    SV* data;           /* Direct SV* - no serialization needed */
    IV prev_idx;        /* Index of prev node (-1 = none) */
    IV next_idx;        /* Index of next node (-1 = none) */
    IV list_idx;        /* Which list this node belongs to */
    IV node_id;         /* Stable ID for Perl object references */
#ifdef USE_ITHREADS
    void* data_interp;  /* Interpreter that owns data SV */
#endif
} DoublyNodeSlot;

/* List metadata */
typedef struct DoublyListMeta {
    IV head_idx;        /* Index of first node (-1 = empty placeholder) */
    IV tail_idx;        /* Index of last node */
    IV length;          /* Number of nodes with data */
    IV refcount;        /* Reference count for GC */
    int destroyed;      /* Flag to mark as destroyed */
} DoublyListMeta;

/* Global registries */
static DoublyListMeta* g_lists = NULL;
static IV g_lists_size = 0;
static IV g_lists_count = 0;

static DoublyNodeSlot* g_nodes = NULL;
static IV g_nodes_size = 0;
static IV g_nodes_count = 0;
static IV g_next_node_id = 1;

/* Free list for node reuse */
static IV* g_free_nodes = NULL;
static IV g_free_nodes_size = 0;
static IV g_free_nodes_count = 0;

/* Free list for list reuse */
static IV* g_free_lists = NULL;
static IV g_free_lists_size = 0;
static IV g_free_lists_count = 0;

/* Thread safety */
#ifdef USE_ITHREADS
static perl_mutex doubly_mutex;
static int doubly_mutex_initialized = 0;
#define DOUBLY_LOCK()   MUTEX_LOCK(&doubly_mutex)
#define DOUBLY_UNLOCK() MUTEX_UNLOCK(&doubly_mutex)
#else
#define DOUBLY_LOCK()
#define DOUBLY_UNLOCK()
#endif

static int doubly_initialized = 0;

/* ============================================
   Custom OPs for hot paths
   ============================================ */

static XOP doubly_data_get_xop;
static XOP doubly_data_set_xop;
static XOP doubly_length_xop;
static XOP doubly_next_xop;
static XOP doubly_prev_xop;
static XOP doubly_start_xop;
static XOP doubly_end_xop;
static XOP doubly_is_start_xop;
static XOP doubly_is_end_xop;

/* Forward declarations for helper functions used by custom ops */
static IV list_length(IV list_idx);
static IV list_head_node_id(IV list_idx);
static IV list_tail_node_id(IV list_idx);
static IV list_next_node_id(IV list_idx, IV current_node_id);
static IV list_prev_node_id(IV list_idx, IV current_node_id);
static int list_is_start_node(IV list_idx, IV node_id);
static int list_is_end_node(IV list_idx, IV node_id);
static SV* list_data_by_node_id(pTHX_ IV list_idx, IV node_id);
static void list_set_data_by_node_id(pTHX_ IV list_idx, IV node_id, SV* data);
static void list_incref(IV list_idx);

/* ============================================
   Initialization
   ============================================ */

static void ensure_lists_capacity(IV needed) {
    if (needed >= g_lists_size) {
        IV new_size = g_lists_size ? g_lists_size * 2 : 16;
        IV i;
        while (new_size <= needed) new_size *= 2;
        Renew(g_lists, new_size, DoublyListMeta);
        for (i = g_lists_size; i < new_size; i++) {
            g_lists[i].head_idx = -1;
            g_lists[i].tail_idx = -1;
            g_lists[i].length = 0;
            g_lists[i].refcount = 0;
            g_lists[i].destroyed = 1;
        }
        g_lists_size = new_size;
    }
}

static void ensure_nodes_capacity(IV needed) {
    if (needed >= g_nodes_size) {
        IV new_size = g_nodes_size ? g_nodes_size * 2 : 64;
        IV i;
        while (new_size <= needed) new_size *= 2;
        Renew(g_nodes, new_size, DoublyNodeSlot);
        for (i = g_nodes_size; i < new_size; i++) {
            g_nodes[i].data = NULL;
            g_nodes[i].prev_idx = -1;
            g_nodes[i].next_idx = -1;
            g_nodes[i].list_idx = -1;
            g_nodes[i].node_id = 0;
#ifdef USE_ITHREADS
            g_nodes[i].data_interp = NULL;
#endif
        }
        g_nodes_size = new_size;
    }
}

static void doubly_init(pTHX) {
#ifdef USE_ITHREADS
    if (!doubly_mutex_initialized) {
        MUTEX_INIT(&doubly_mutex);
        doubly_mutex_initialized = 1;
    }
#endif
    if (!doubly_initialized) {
        g_lists_size = 16;
        Newxz(g_lists, g_lists_size, DoublyListMeta);
        g_nodes_size = 64;
        Newxz(g_nodes, g_nodes_size, DoublyNodeSlot);
        g_free_nodes_size = 16;
        Newxz(g_free_nodes, g_free_nodes_size, IV);
        g_free_lists_size = 16;
        Newxz(g_free_lists, g_free_lists_size, IV);
        doubly_initialized = 1;
    }
}

/* ============================================
   Node Management
   ============================================ */

/* Allocate a new node slot, returns index */
static IV alloc_node(pTHX) {
    IV idx;

    /* Check free list first */
    if (g_free_nodes_count > 0) {
        idx = g_free_nodes[--g_free_nodes_count];
    } else {
        ensure_nodes_capacity(g_nodes_count);
        idx = g_nodes_count++;
    }

    /* Initialize node */
    g_nodes[idx].data = NULL;
    g_nodes[idx].prev_idx = -1;
    g_nodes[idx].next_idx = -1;
    g_nodes[idx].list_idx = -1;
    g_nodes[idx].node_id = g_next_node_id++;
#ifdef USE_ITHREADS
    g_nodes[idx].data_interp = NULL;
#endif

    return idx;
}

/* Free a node slot (add to free list) */
static void free_node(pTHX_ IV idx) {
    DoublyNodeSlot* node;

    if (idx < 0 || idx >= g_nodes_count) return;

    node = &g_nodes[idx];

    /* Decrement SV refcount if not during global destruction
     * and only if we're in the interpreter that owns the SV */
    if (node->data && !PL_dirty) {
#ifdef USE_ITHREADS
        /* Only free if this interpreter owns the SV */
        if (node->data_interp == PERL_GET_THX) {
            SvREFCNT_dec(node->data);
        }
        /* Note: if we're not the owner, we "leak" this SV intentionally.
         * The owning interpreter will clean it up during its destruction. */
#else
        SvREFCNT_dec(node->data);
#endif
    }
    node->data = NULL;
    node->prev_idx = -1;
    node->next_idx = -1;
    node->list_idx = -1;
    node->node_id = 0;
#ifdef USE_ITHREADS
    node->data_interp = NULL;
#endif

    /* Add to free list */
    if (g_free_nodes_count >= g_free_nodes_size) {
        g_free_nodes_size *= 2;
        Renew(g_free_nodes, g_free_nodes_size, IV);
    }
    g_free_nodes[g_free_nodes_count++] = idx;
}

/* Create a node with data */
static IV create_node(pTHX_ SV* data, IV list_idx) {
    IV idx = alloc_node(aTHX);
    DoublyNodeSlot* node = &g_nodes[idx];

    if (data && SvOK(data)) {
        node->data = newSVsv(data);  /* Copy the SV */
    } else {
        node->data = newSV(0);  /* Create empty SV for undef */
    }
    node->list_idx = list_idx;
#ifdef USE_ITHREADS
    node->data_interp = PERL_GET_THX;  /* Track which interpreter owns this SV */
#endif

    return idx;
}

/* ============================================
   List Management
   ============================================ */

/* Allocate a new list, returns index */
static IV alloc_list(pTHX) {
    IV idx;

    /* Check free list first */
    if (g_free_lists_count > 0) {
        idx = g_free_lists[--g_free_lists_count];
    } else {
        ensure_lists_capacity(g_lists_count);
        idx = g_lists_count++;
    }

    /* Initialize list */
    g_lists[idx].head_idx = -1;
    g_lists[idx].tail_idx = -1;
    g_lists[idx].length = 0;
    g_lists[idx].refcount = 1;
    g_lists[idx].destroyed = 0;

    return idx;
}

/* Get list by index - caller must hold lock */
static DoublyListMeta* get_list(IV idx) {
    if (idx < 0 || idx >= g_lists_count) return NULL;
    if (g_lists[idx].destroyed) return NULL;
    return &g_lists[idx];
}

/* Get node by index - caller must hold lock */
static DoublyNodeSlot* get_node(IV idx) {
    if (idx < 0 || idx >= g_nodes_count) return NULL;
    return &g_nodes[idx];
}

/* Find node by node_id in a list - caller must hold lock */
static IV find_node_by_id(DoublyListMeta* list, IV node_id) {
    IV idx;
    DoublyNodeSlot* node;

    if (!list || list->destroyed) return -1;

    idx = list->head_idx;
    while (idx >= 0) {
        node = get_node(idx);
        if (!node) break;
        if (node->node_id == node_id) {
            return idx;
        }
        idx = node->next_idx;
    }
    return -1;
}

/* Create a new list with optional initial data */
static IV new_list(pTHX_ SV* data) {
    IV list_idx;
    IV node_idx;
    DoublyListMeta* list;

    DOUBLY_LOCK();

    list_idx = alloc_list(aTHX);
    list = &g_lists[list_idx];

    /* Create initial placeholder node */
    node_idx = create_node(aTHX_ data, list_idx);
    list->head_idx = node_idx;
    list->tail_idx = node_idx;

    /* If data is defined, length is 1, otherwise 0 (empty placeholder) */
    list->length = (data && SvOK(data)) ? 1 : 0;

    DOUBLY_UNLOCK();

    return list_idx;
}

/* Increment refcount */
static void list_incref(IV list_idx) {
    DoublyListMeta* list;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        list->refcount++;
    }
    DOUBLY_UNLOCK();
}

/* Decrement refcount, free if zero */
static void list_decref(pTHX_ IV list_idx) {
    DoublyListMeta* list;
    IV node_idx, next_idx;
    SV** svs_to_free = NULL;
    IV svs_count = 0;
    IV svs_capacity = 0;
    IV i;

    DOUBLY_LOCK();

    list = get_list(list_idx);
    if (list) {
        list->refcount--;
        if (list->refcount <= 0) {
            /* Collect all SVs that need freeing - do NOT free while holding lock */
            node_idx = list->head_idx;
            while (node_idx >= 0) {
                DoublyNodeSlot* node = get_node(node_idx);
                if (node && node->data && !PL_dirty) {
#ifdef USE_ITHREADS
                    if (node->data_interp == PERL_GET_THX) {
#endif
                        /* Collect this SV for later freeing */
                        if (svs_count >= svs_capacity) {
                            svs_capacity = svs_capacity ? svs_capacity * 2 : 16;
                            Renew(svs_to_free, svs_capacity, SV*);
                        }
                        svs_to_free[svs_count++] = node->data;
                        node->data = NULL;  /* Prevent double-free */
#ifdef USE_ITHREADS
                    }
#endif
                }
                next_idx = node ? node->next_idx : -1;
                
                /* Clear node and add to free list */
                if (node) {
                    node->data = NULL;
                    node->prev_idx = -1;
                    node->next_idx = -1;
                    node->list_idx = -1;
                    node->node_id = 0;
#ifdef USE_ITHREADS
                    node->data_interp = NULL;
#endif
                    if (g_free_nodes_count >= g_free_nodes_size) {
                        g_free_nodes_size *= 2;
                        Renew(g_free_nodes, g_free_nodes_size, IV);
                    }
                    g_free_nodes[g_free_nodes_count++] = node_idx;
                }
                node_idx = next_idx;
            }

            list->head_idx = -1;
            list->tail_idx = -1;
            list->length = 0;
            list->destroyed = 1;

            /* Add to free list */
            if (g_free_lists_count >= g_free_lists_size) {
                g_free_lists_size *= 2;
                Renew(g_free_lists, g_free_lists_size, IV);
            }
            g_free_lists[g_free_lists_count++] = list_idx;
        }
    }
    DOUBLY_UNLOCK();
    
    /* Now free SVs OUTSIDE the lock - prevents deadlock with nested doubly objects */
    for (i = 0; i < svs_count; i++) {
        SvREFCNT_dec(svs_to_free[i]);
    }
    if (svs_to_free) {
        Safefree(svs_to_free);
    }
}

/* ============================================
   List Operations
   ============================================ */

/* Get length */
static IV list_length(IV list_idx) {
    DoublyListMeta* list;
    IV len = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        len = list->length;
    }
    DOUBLY_UNLOCK();

    return len;
}

/* Get head node_id */
static IV list_head_node_id(IV list_idx) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_id = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && list->head_idx >= 0) {
        node = get_node(list->head_idx);
        if (node) {
            node_id = node->node_id;
        }
    }
    DOUBLY_UNLOCK();

    return node_id;
}

/* Get tail node_id */
static IV list_tail_node_id(IV list_idx) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_id = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && list->tail_idx >= 0) {
        node = get_node(list->tail_idx);
        if (node) {
            node_id = node->node_id;
        }
    }
    DOUBLY_UNLOCK();

    return node_id;
}

/* Get next node_id */
static IV list_next_node_id(IV list_idx, IV current_node_id) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_idx, next_id = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        node_idx = find_node_by_id(list, current_node_id);
        if (node_idx >= 0) {
            node = get_node(node_idx);
            if (node && node->next_idx >= 0) {
                DoublyNodeSlot* next_node = get_node(node->next_idx);
                if (next_node) {
                    next_id = next_node->node_id;
                }
            }
        }
    }
    DOUBLY_UNLOCK();

    return next_id;
}

/* Get prev node_id */
static IV list_prev_node_id(IV list_idx, IV current_node_id) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_idx, prev_id = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        node_idx = find_node_by_id(list, current_node_id);
        if (node_idx >= 0) {
            node = get_node(node_idx);
            if (node && node->prev_idx >= 0) {
                DoublyNodeSlot* prev_node = get_node(node->prev_idx);
                if (prev_node) {
                    prev_id = prev_node->node_id;
                }
            }
        }
    }
    DOUBLY_UNLOCK();

    return prev_id;
}

/* Check if node is at start */
static int list_is_start_node(IV list_idx, IV node_id) {
    DoublyListMeta* list;
    DoublyNodeSlot* head;
    int is_start = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && list->head_idx >= 0) {
        head = get_node(list->head_idx);
        if (head && head->node_id == node_id) {
            is_start = 1;
        }
    }
    DOUBLY_UNLOCK();

    return is_start;
}

/* Check if node is at end */
static int list_is_end_node(IV list_idx, IV node_id) {
    DoublyListMeta* list;
    DoublyNodeSlot* tail;
    int is_end = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && list->tail_idx >= 0) {
        tail = get_node(list->tail_idx);
        if (tail && tail->node_id == node_id) {
            is_end = 1;
        }
    }
    DOUBLY_UNLOCK();

    return is_end;
}

/* Get data by node_id */
static SV* list_data_by_node_id(pTHX_ IV list_idx, IV node_id) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_idx;
    SV* result = &PL_sv_undef;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        node_idx = find_node_by_id(list, node_id);
        if (node_idx >= 0) {
            node = get_node(node_idx);
            if (node && node->data) {
                result = newSVsv(node->data);
            }
        }
    }
    DOUBLY_UNLOCK();

    return result;
}

/* Set data by node_id */
static void list_set_data_by_node_id(pTHX_ IV list_idx, IV node_id, SV* data) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_idx;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        node_idx = find_node_by_id(list, node_id);
        if (node_idx >= 0) {
            node = get_node(node_idx);
            if (node) {
                /* Free old data */
#ifdef USE_ITHREADS
                if (node->data && node->data_interp == PERL_GET_THX) {
                    SvREFCNT_dec(node->data);
                }
#else
                if (node->data) {
                    SvREFCNT_dec(node->data);
                }
#endif
                /* Store new data */
                if (data && SvOK(data)) {
                    node->data = newSVsv(data);
                } else {
                    node->data = newSV(0);
                }
#ifdef USE_ITHREADS
                node->data_interp = PERL_GET_THX;
#endif
            }
        }
    }
    DOUBLY_UNLOCK();
}

/* Add at end */
static void list_add(pTHX_ IV list_idx, SV* data) {
    DoublyListMeta* list;
    DoublyNodeSlot* tail;
    IV new_idx;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        if (list->length == 0 && list->head_idx >= 0) {
            /* Empty list with placeholder - set data on existing node */
            tail = get_node(list->head_idx);
            if (tail) {
#ifdef USE_ITHREADS
                /* Only free if this interpreter owns the SV */
                if (tail->data && tail->data_interp == PERL_GET_THX) {
                    SvREFCNT_dec(tail->data);
                }
#else
                if (tail->data) {
                    SvREFCNT_dec(tail->data);
                }
#endif
                tail->data = newSVsv(data);
#ifdef USE_ITHREADS
                tail->data_interp = PERL_GET_THX;
#endif
                list->length = 1;
            }
        } else {
            /* Create new node and append */
            new_idx = create_node(aTHX_ data, list_idx);
            tail = get_node(list->tail_idx);
            if (tail) {
                tail->next_idx = new_idx;
                g_nodes[new_idx].prev_idx = list->tail_idx;
            }
            list->tail_idx = new_idx;
            list->length++;
        }
    }
    DOUBLY_UNLOCK();
}

/* Insert before node_id - returns new node's ID */
static IV list_insert_before_node_id(pTHX_ IV list_idx, IV node_id, SV* data) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    DoublyNodeSlot* new_node;
    IV node_idx, new_idx;
    IV new_id = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        if (list->length == 0 && list->head_idx >= 0) {
            /* Empty list with placeholder - set data on existing node */
            node = get_node(list->head_idx);
            if (node) {
#ifdef USE_ITHREADS
                if (node->data && node->data_interp == PERL_GET_THX) {
                    SvREFCNT_dec(node->data);
                }
#else
                if (node->data) {
                    SvREFCNT_dec(node->data);
                }
#endif
                node->data = newSVsv(data);
#ifdef USE_ITHREADS
                node->data_interp = PERL_GET_THX;
#endif
                list->length = 1;
                new_id = node->node_id;
            }
            DOUBLY_UNLOCK();
            return new_id;
        }

        node_idx = find_node_by_id(list, node_id);
        if (node_idx >= 0) {
            node = get_node(node_idx);
            new_idx = create_node(aTHX_ data, list_idx);
            new_node = get_node(new_idx);
            new_id = new_node->node_id;

            if (node->prev_idx >= 0) {
                g_nodes[node->prev_idx].next_idx = new_idx;
                new_node->prev_idx = node->prev_idx;
            } else {
                list->head_idx = new_idx;
            }
            new_node->next_idx = node_idx;
            node->prev_idx = new_idx;
            list->length++;
        }
    }
    DOUBLY_UNLOCK();

    return new_id;
}

/* Insert after node_id - returns new node's ID */
static IV list_insert_after_node_id(pTHX_ IV list_idx, IV node_id, SV* data) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    DoublyNodeSlot* new_node;
    IV node_idx, new_idx;
    IV new_id = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        if (list->length == 0 && list->head_idx >= 0) {
            /* Empty list with placeholder - set data on existing node */
            node = get_node(list->head_idx);
            if (node) {
#ifdef USE_ITHREADS
                if (node->data && node->data_interp == PERL_GET_THX) {
                    SvREFCNT_dec(node->data);
                }
#else
                if (node->data) {
                    SvREFCNT_dec(node->data);
                }
#endif
                node->data = newSVsv(data);
#ifdef USE_ITHREADS
                node->data_interp = PERL_GET_THX;
#endif
                list->length = 1;
                new_id = node->node_id;
            }
            DOUBLY_UNLOCK();
            return new_id;
        }

        node_idx = find_node_by_id(list, node_id);
        if (node_idx >= 0) {
            node = get_node(node_idx);
            new_idx = create_node(aTHX_ data, list_idx);
            new_node = get_node(new_idx);
            new_id = new_node->node_id;

            if (node->next_idx >= 0) {
                g_nodes[node->next_idx].prev_idx = new_idx;
                new_node->next_idx = node->next_idx;
            } else {
                list->tail_idx = new_idx;
            }
            new_node->prev_idx = node_idx;
            node->next_idx = new_idx;
            list->length++;
        }
    }
    DOUBLY_UNLOCK();

    return new_id;
}

/* Insert at start */
static void list_insert_at_start(pTHX_ IV list_idx, SV* data) {
    DoublyListMeta* list;
    DoublyNodeSlot* head;
    DoublyNodeSlot* new_node;
    IV new_idx;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        if (list->length == 0 && list->head_idx >= 0) {
            /* Empty list with placeholder */
            head = get_node(list->head_idx);
            if (head) {
#ifdef USE_ITHREADS
                if (head->data && head->data_interp == PERL_GET_THX) {
                    SvREFCNT_dec(head->data);
                }
#else
                if (head->data) {
                    SvREFCNT_dec(head->data);
                }
#endif
                head->data = newSVsv(data);
#ifdef USE_ITHREADS
                head->data_interp = PERL_GET_THX;
#endif
                list->length = 1;
            }
        } else {
            /* Create new node and prepend */
            new_idx = create_node(aTHX_ data, list_idx);
            new_node = get_node(new_idx);
            head = get_node(list->head_idx);

            new_node->next_idx = list->head_idx;
            if (head) {
                head->prev_idx = new_idx;
            }
            list->head_idx = new_idx;
            list->length++;
        }
    }
    DOUBLY_UNLOCK();
}

/* Insert at end (same as add) */
static void list_insert_at_end(pTHX_ IV list_idx, SV* data) {
    list_add(aTHX_ list_idx, data);
}

/* Get node at position - caller must hold lock */
static IV get_node_at_pos(DoublyListMeta* list, IV pos) {
    IV node_idx;
    DoublyNodeSlot* node;
    IV i;

    if (!list || list->destroyed || list->head_idx < 0) return -1;

    node_idx = list->head_idx;
    for (i = 0; i < pos && node_idx >= 0; i++) {
        node = get_node(node_idx);
        if (!node) break;
        node_idx = node->next_idx;
    }

    return node_idx;
}

/* Insert at position - data becomes the node at position pos */
static void list_insert_at_pos(pTHX_ IV list_idx, IV pos, SV* data) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    DoublyNodeSlot* new_node;
    IV node_idx, new_idx;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list) {
        if (list->length == 0 || pos == 0) {
            /* Insert at head */
            DOUBLY_UNLOCK();
            list_insert_at_start(aTHX_ list_idx, data);
            return;
        }

        if (pos >= list->length) {
            /* Insert at end if pos is beyond list */
            DOUBLY_UNLOCK();
            list_add(aTHX_ list_idx, data);
            return;
        }

        /* Insert before the node at pos (so new node becomes pos) */
        node_idx = get_node_at_pos(list, pos);
        if (node_idx >= 0) {
            node = get_node(node_idx);
            new_idx = create_node(aTHX_ data, list_idx);
            new_node = get_node(new_idx);

            /* Insert before node */
            new_node->next_idx = node_idx;
            new_node->prev_idx = node->prev_idx;
            if (node->prev_idx >= 0) {
                g_nodes[node->prev_idx].next_idx = new_idx;
            } else {
                list->head_idx = new_idx;
            }
            node->prev_idx = new_idx;
            list->length++;
        }
    }
    DOUBLY_UNLOCK();
}

/* Remove result structure */
typedef struct {
    SV* data;
    IV next_node_id;
} RemoveResult;

/* Remove by node_id - returns data and next node_id */
static RemoveResult list_remove_by_node_id(pTHX_ IV list_idx, IV node_id) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_idx;
    RemoveResult result = { &PL_sv_undef, 0 };

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && list->length > 0) {
        node_idx = find_node_by_id(list, node_id);
        if (node_idx >= 0) {
            node = get_node(node_idx);
            if (node) {
                /* Get data before freeing */
                if (node->data) {
                    result.data = newSVsv(node->data);
                }

                /* Get next node ID before modification */
                if (node->next_idx >= 0) {
                    DoublyNodeSlot* next = get_node(node->next_idx);
                    if (next) result.next_node_id = next->node_id;
                } else if (node->prev_idx >= 0) {
                    DoublyNodeSlot* prev = get_node(node->prev_idx);
                    if (prev) result.next_node_id = prev->node_id;
                }

                /* Unlink the node */
                if (node->prev_idx >= 0 && node->next_idx >= 0) {
                    /* Middle node */
                    g_nodes[node->prev_idx].next_idx = node->next_idx;
                    g_nodes[node->next_idx].prev_idx = node->prev_idx;
                    free_node(aTHX_ node_idx);
                    list->length--;
                } else if (node->prev_idx >= 0) {
                    /* Tail node */
                    list->tail_idx = node->prev_idx;
                    g_nodes[node->prev_idx].next_idx = -1;
                    free_node(aTHX_ node_idx);
                    list->length--;
                } else if (node->next_idx >= 0) {
                    /* Head node */
                    list->head_idx = node->next_idx;
                    g_nodes[node->next_idx].prev_idx = -1;
                    free_node(aTHX_ node_idx);
                    list->length--;
                } else {
                    /* Only node - just clear data, keep placeholder */
                    if (node->data) {
#ifdef USE_ITHREADS
                        if (node->data_interp == PERL_GET_THX) {
                            SvREFCNT_dec(node->data);
                        }
#else
                        SvREFCNT_dec(node->data);
#endif
                        node->data = newSV(0);
#ifdef USE_ITHREADS
                        node->data_interp = PERL_GET_THX;
#endif
                    }
                    list->length = 0;
                    result.next_node_id = 0;
                }
            }
        }
    }
    DOUBLY_UNLOCK();

    return result;
}

/* Remove from start */
static SV* list_remove_from_start(pTHX_ IV list_idx) {
    DoublyListMeta* list;
    DoublyNodeSlot* head;
    SV* result = &PL_sv_undef;
    IV head_idx;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && list->length > 0 && list->head_idx >= 0) {
        head_idx = list->head_idx;
        head = get_node(head_idx);
        if (head) {
            if (head->data) {
                result = newSVsv(head->data);
            }

            if (head->next_idx >= 0) {
                list->head_idx = head->next_idx;
                g_nodes[head->next_idx].prev_idx = -1;
                free_node(aTHX_ head_idx);
                list->length--;
            } else {
                /* Only node - clear data, keep placeholder */
                if (head->data) {
#ifdef USE_ITHREADS
                    if (head->data_interp == PERL_GET_THX) {
                        SvREFCNT_dec(head->data);
                    }
#else
                    SvREFCNT_dec(head->data);
#endif
                    head->data = newSV(0);
#ifdef USE_ITHREADS
                    head->data_interp = PERL_GET_THX;
#endif
                }
                list->length = 0;
            }
        }
    }
    DOUBLY_UNLOCK();

    return result;
}

/* Remove from end */
static SV* list_remove_from_end(pTHX_ IV list_idx) {
    DoublyListMeta* list;
    DoublyNodeSlot* tail;
    SV* result = &PL_sv_undef;
    IV tail_idx;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && list->length > 0 && list->tail_idx >= 0) {
        tail_idx = list->tail_idx;
        tail = get_node(tail_idx);
        if (tail) {
            if (tail->data) {
                result = newSVsv(tail->data);
            }

            if (tail->prev_idx >= 0) {
                list->tail_idx = tail->prev_idx;
                g_nodes[tail->prev_idx].next_idx = -1;
                free_node(aTHX_ tail_idx);
                list->length--;
            } else {
                /* Only node - clear data, keep placeholder */
                if (tail->data) {
#ifdef USE_ITHREADS
                    if (tail->data_interp == PERL_GET_THX) {
                        SvREFCNT_dec(tail->data);
                    }
#else
                    SvREFCNT_dec(tail->data);
#endif
                    tail->data = newSV(0);
#ifdef USE_ITHREADS
                    tail->data_interp = PERL_GET_THX;
#endif
                }
                list->length = 0;
            }
        }
    }
    DOUBLY_UNLOCK();

    return result;
}

/* Remove at position */
static SV* list_remove_at_pos(pTHX_ IV list_idx, IV pos) {
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_idx;
    SV* result = &PL_sv_undef;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && list->length > 0) {
        node_idx = get_node_at_pos(list, pos);
        if (node_idx >= 0) {
            node = get_node(node_idx);
            if (node) {
                if (node->data) {
                    result = newSVsv(node->data);
                }

                if (node->prev_idx >= 0 && node->next_idx >= 0) {
                    /* Middle node */
                    g_nodes[node->prev_idx].next_idx = node->next_idx;
                    g_nodes[node->next_idx].prev_idx = node->prev_idx;
                    free_node(aTHX_ node_idx);
                    list->length--;
                } else if (node->prev_idx >= 0) {
                    /* Tail node */
                    list->tail_idx = node->prev_idx;
                    g_nodes[node->prev_idx].next_idx = -1;
                    free_node(aTHX_ node_idx);
                    list->length--;
                } else if (node->next_idx >= 0) {
                    /* Head node */
                    list->head_idx = node->next_idx;
                    g_nodes[node->next_idx].prev_idx = -1;
                    free_node(aTHX_ node_idx);
                    list->length--;
                } else {
                    /* Only node - clear data */
                    if (node->data) {
#ifdef USE_ITHREADS
                        if (node->data_interp == PERL_GET_THX) {
                            SvREFCNT_dec(node->data);
                        }
#else
                        SvREFCNT_dec(node->data);
#endif
                        node->data = newSV(0);
#ifdef USE_ITHREADS
                        node->data_interp = PERL_GET_THX;
#endif
                    }
                    list->length = 0;
                }
            }
        }
    }
    DOUBLY_UNLOCK();

    return result;
}

/* Destroy list (mark as destroyed, free nodes) */
static void list_destroy(pTHX_ IV list_idx) {
    DoublyListMeta* list;
    IV node_idx, next_idx;
    SV** svs_to_free = NULL;
    IV svs_count = 0;
    IV svs_capacity = 0;
    IV i;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && !list->destroyed) {
        list->destroyed = 1;

        /* Collect all SVs that need freeing */
        node_idx = list->head_idx;
        while (node_idx >= 0) {
            DoublyNodeSlot* node = get_node(node_idx);
            if (node && node->data && !PL_dirty) {
#ifdef USE_ITHREADS
                if (node->data_interp == PERL_GET_THX) {
#endif
                    if (svs_count >= svs_capacity) {
                        svs_capacity = svs_capacity ? svs_capacity * 2 : 16;
                        Renew(svs_to_free, svs_capacity, SV*);
                    }
                    svs_to_free[svs_count++] = node->data;
                    node->data = NULL;
#ifdef USE_ITHREADS
                }
#endif
            }
            next_idx = node ? node->next_idx : -1;
            
            /* Clear node and add to free list */
            if (node) {
                node->data = NULL;
                node->prev_idx = -1;
                node->next_idx = -1;
                node->list_idx = -1;
                node->node_id = 0;
#ifdef USE_ITHREADS
                node->data_interp = NULL;
#endif
                if (g_free_nodes_count >= g_free_nodes_size) {
                    g_free_nodes_size *= 2;
                    Renew(g_free_nodes, g_free_nodes_size, IV);
                }
                g_free_nodes[g_free_nodes_count++] = node_idx;
            }
            node_idx = next_idx;
        }

        list->head_idx = -1;
        list->tail_idx = -1;
        list->length = 0;
    }
    DOUBLY_UNLOCK();
    
    /* Free SVs OUTSIDE the lock */
    for (i = 0; i < svs_count; i++) {
        SvREFCNT_dec(svs_to_free[i]);
    }
    if (svs_to_free) {
        Safefree(svs_to_free);
    }
}

/* ============================================
   Custom OP implementations
   ============================================ */

/* Helper to extract list_idx and node_id from doubly object */
static int get_doubly_info(pTHX_ SV *obj, IV *list_idx, IV *node_id) {
    HV *hash;
    SV **id_sv, **node_id_sv;

    if (!SvROK(obj) || SvTYPE(SvRV(obj)) != SVt_PVHV) return 0;

    hash = (HV*)SvRV(obj);
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);

    *list_idx = id_sv ? SvIV(*id_sv) : -1;
    *node_id = node_id_sv ? SvIV(*node_id_sv) : 0;

    return 1;
}

#ifdef USE_ITHREADS
static UV get_doubly_owner_tid(pTHX_ SV *obj) {
    HV *hash;
    SV **owner_tid_sv;

    if (!SvROK(obj) || SvTYPE(SvRV(obj)) != SVt_PVHV) return PTR2UV(PERL_GET_THX);

    hash = (HV*)SvRV(obj);
    owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
    return owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
}
#endif

/* pp_doubly_data_get - fast data getter */
static OP* pp_doubly_data_get(pTHX) {
    dSP;
    SV *obj = TOPs;
    IV list_idx, node_id;
    SV *result;

    if (!get_doubly_info(aTHX_ obj, &list_idx, &node_id)) {
        SETs(&PL_sv_undef);
        RETURN;
    }

    result = list_data_by_node_id(aTHX_ list_idx, node_id);
    SETs(sv_2mortal(result));
    RETURN;
}

/* pp_doubly_data_set - fast data setter */
static OP* pp_doubly_data_set(pTHX) {
    dSP;
    SV *val = POPs;
    SV *obj = TOPs;
    IV list_idx, node_id;
    SV *result;

    if (!get_doubly_info(aTHX_ obj, &list_idx, &node_id)) {
        SETs(&PL_sv_undef);
        RETURN;
    }

    list_set_data_by_node_id(aTHX_ list_idx, node_id, val);
    result = list_data_by_node_id(aTHX_ list_idx, node_id);
    SETs(sv_2mortal(result));
    RETURN;
}

/* pp_doubly_length - fast length getter */
static OP* pp_doubly_length(pTHX) {
    dSP;
    SV *obj = TOPs;
    IV list_idx, node_id;

    if (!get_doubly_info(aTHX_ obj, &list_idx, &node_id)) {
        SETs(sv_2mortal(newSViv(0)));
        RETURN;
    }

    SETs(sv_2mortal(newSViv(list_length(list_idx))));
    RETURN;
}

/* Forward declaration for create_doubly_object */
static SV* create_doubly_object(pTHX_ IV list_idx, IV node_id
#ifdef USE_ITHREADS
    , UV owner_tid
#endif
);

/* pp_doubly_next - fast next navigation */
static OP* pp_doubly_next(pTHX) {
    dSP;
    SV *obj = TOPs;
    IV list_idx, node_id, next_node_id;
#ifdef USE_ITHREADS
    UV owner_tid;
#endif

    if (!get_doubly_info(aTHX_ obj, &list_idx, &node_id)) {
        SETs(&PL_sv_undef);
        RETURN;
    }

    next_node_id = list_next_node_id(list_idx, node_id);

    if (next_node_id == 0) {
        SETs(&PL_sv_undef);
    } else {
#ifdef USE_ITHREADS
        owner_tid = get_doubly_owner_tid(aTHX_ obj);
#endif
        list_incref(list_idx);
#ifdef USE_ITHREADS
        SETs(sv_2mortal(create_doubly_object(aTHX_ list_idx, next_node_id, owner_tid)));
#else
        SETs(sv_2mortal(create_doubly_object(aTHX_ list_idx, next_node_id)));
#endif
    }
    RETURN;
}

/* pp_doubly_prev - fast prev navigation */
static OP* pp_doubly_prev(pTHX) {
    dSP;
    SV *obj = TOPs;
    IV list_idx, node_id, prev_node_id;
#ifdef USE_ITHREADS
    UV owner_tid;
#endif

    if (!get_doubly_info(aTHX_ obj, &list_idx, &node_id)) {
        SETs(&PL_sv_undef);
        RETURN;
    }

    prev_node_id = list_prev_node_id(list_idx, node_id);

    if (prev_node_id == 0) {
        SETs(&PL_sv_undef);
    } else {
#ifdef USE_ITHREADS
        owner_tid = get_doubly_owner_tid(aTHX_ obj);
#endif
        list_incref(list_idx);
#ifdef USE_ITHREADS
        SETs(sv_2mortal(create_doubly_object(aTHX_ list_idx, prev_node_id, owner_tid)));
#else
        SETs(sv_2mortal(create_doubly_object(aTHX_ list_idx, prev_node_id)));
#endif
    }
    RETURN;
}

/* pp_doubly_start - fast start navigation */
static OP* pp_doubly_start(pTHX) {
    dSP;
    SV *obj = TOPs;
    IV list_idx, node_id, head_node_id;
#ifdef USE_ITHREADS
    UV owner_tid;
#endif

    if (!get_doubly_info(aTHX_ obj, &list_idx, &node_id)) {
        SETs(&PL_sv_undef);
        RETURN;
    }

    head_node_id = list_head_node_id(list_idx);

#ifdef USE_ITHREADS
    owner_tid = get_doubly_owner_tid(aTHX_ obj);
#endif
    list_incref(list_idx);
#ifdef USE_ITHREADS
    SETs(sv_2mortal(create_doubly_object(aTHX_ list_idx, head_node_id, owner_tid)));
#else
    SETs(sv_2mortal(create_doubly_object(aTHX_ list_idx, head_node_id)));
#endif
    RETURN;
}

/* pp_doubly_end - fast end navigation */
static OP* pp_doubly_end(pTHX) {
    dSP;
    SV *obj = TOPs;
    IV list_idx, node_id, tail_node_id;
#ifdef USE_ITHREADS
    UV owner_tid;
#endif

    if (!get_doubly_info(aTHX_ obj, &list_idx, &node_id)) {
        SETs(&PL_sv_undef);
        RETURN;
    }

    tail_node_id = list_tail_node_id(list_idx);

#ifdef USE_ITHREADS
    owner_tid = get_doubly_owner_tid(aTHX_ obj);
#endif
    list_incref(list_idx);
#ifdef USE_ITHREADS
    SETs(sv_2mortal(create_doubly_object(aTHX_ list_idx, tail_node_id, owner_tid)));
#else
    SETs(sv_2mortal(create_doubly_object(aTHX_ list_idx, tail_node_id)));
#endif
    RETURN;
}

/* pp_doubly_is_start - fast is_start check */
static OP* pp_doubly_is_start(pTHX) {
    dSP;
    SV *obj = TOPs;
    IV list_idx, node_id;

    if (!get_doubly_info(aTHX_ obj, &list_idx, &node_id)) {
        SETs(&PL_sv_no);
        RETURN;
    }

    SETs(list_is_start_node(list_idx, node_id) ? &PL_sv_yes : &PL_sv_no);
    RETURN;
}

/* pp_doubly_is_end - fast is_end check */
static OP* pp_doubly_is_end(pTHX) {
    dSP;
    SV *obj = TOPs;
    IV list_idx, node_id;

    if (!get_doubly_info(aTHX_ obj, &list_idx, &node_id)) {
        SETs(&PL_sv_no);
        RETURN;
    }

    SETs(list_is_end_node(list_idx, node_id) ? &PL_sv_yes : &PL_sv_no);
    RETURN;
}

/* ============================================
   Call Checker - replaces method calls with custom ops at compile time
   ============================================ */

typedef OP* (*doubly_ppfunc)(pTHX);

/* Call checker for 1-arg methods: $list->method */
static OP* doubly_call_checker_1arg(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    doubly_ppfunc ppfunc = (doubly_ppfunc)SvIVX(ckobj);
    OP *pushop, *cvop, *selfop;
    OP *newop;

    PERL_UNUSED_ARG(namegv);

    /* Navigate to first child */
    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    /* Get args: pushmark -> self -> cv */
    selfop = OpSIBLING(pushop);
    if (!selfop) return entersubop;

    cvop = OpSIBLING(selfop);
    if (!cvop) return entersubop;

    /* Verify exactly 1 arg (selfop's sibling is cvop) */
    if (OpSIBLING(selfop) != cvop) return entersubop;

    /* Detach self from the entersub tree */
    OpMORESIB_set(pushop, cvop);
    OpLASTSIB_set(selfop, NULL);

    /* Create unary custom op with self as child */
    newop = newUNOP(OP_CUSTOM, 0, selfop);
    newop->op_ppaddr = ppfunc;

    op_free(entersubop);
    return newop;
}

/* Call checker for 2-arg methods: $list->method($val) */
static OP* doubly_call_checker_2arg(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    doubly_ppfunc ppfunc = (doubly_ppfunc)SvIVX(ckobj);
    OP *pushop, *cvop, *selfop, *valop;
    OP *newop;

    PERL_UNUSED_ARG(namegv);

    /* Navigate to first child */
    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    /* Get args: pushmark -> self -> val -> cv */
    selfop = OpSIBLING(pushop);
    if (!selfop) return entersubop;

    valop = OpSIBLING(selfop);
    if (!valop) return entersubop;

    cvop = OpSIBLING(valop);
    if (!cvop) return entersubop;

    /* Verify exactly 2 args */
    if (OpSIBLING(valop) != cvop) return entersubop;

    /* Detach self and val from the entersub tree */
    OpMORESIB_set(pushop, cvop);
    OpLASTSIB_set(selfop, NULL);
    OpLASTSIB_set(valop, NULL);

    /* Create binary custom op with self and val as children */
    newop = newBINOP(OP_CUSTOM, 0, selfop, valop);
    newop->op_ppaddr = ppfunc;

    op_free(entersubop);
    return newop;
}

/* Call checker for data() - handles both 1-arg (get) and 2-arg (set) */
static OP* doubly_data_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    OP *pushop, *cvop, *selfop, *valop;
    OP *newop;
    int is_setter;

    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);

    /* Navigate to first child */
    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    /* Get args: pushmark -> self [-> val] -> cv */
    selfop = OpSIBLING(pushop);
    if (!selfop) return entersubop;

    valop = OpSIBLING(selfop);
    if (!valop) return entersubop;

    cvop = OpSIBLING(valop);

    /* Check if 1-arg (getter) or 2-arg (setter) */
    if (cvop && OpSIBLING(valop) == cvop) {
        /* Might be cv directly (1 arg) or we need to check further */
        /* If valop is the cv, then it's 1-arg */
        is_setter = 0;
        cvop = valop;
        valop = NULL;
    } else if (cvop) {
        /* 2-arg setter */
        is_setter = 1;
    } else {
        return entersubop;
    }

    if (is_setter) {
        /* Setter: $list->data($val) */
        OpMORESIB_set(pushop, cvop);
        OpLASTSIB_set(selfop, NULL);
        OpLASTSIB_set(valop, NULL);

        newop = newBINOP(OP_CUSTOM, 0, selfop, valop);
        newop->op_ppaddr = pp_doubly_data_set;
    } else {
        /* Getter: $list->data */
        OpMORESIB_set(pushop, cvop);
        OpLASTSIB_set(selfop, NULL);

        newop = newUNOP(OP_CUSTOM, 0, selfop);
        newop->op_ppaddr = pp_doubly_data_get;
    }

    op_free(entersubop);
    return newop;
}

/* ============================================
   Helper: Create blessed object
   ============================================ */

static SV* create_doubly_object(pTHX_ IV list_idx, IV node_id
#ifdef USE_ITHREADS
    , UV owner_tid
#endif
) {
    HV* hash = newHV();
    hv_store(hash, "_id", 3, newSViv(list_idx), 0);
    hv_store(hash, "_node_id", 8, newSViv(node_id), 0);
#ifdef USE_ITHREADS
    hv_store(hash, "_owner_tid", 10, newSVuv(owner_tid), 0);
#endif
    return sv_bless(newRV_noinc((SV*)hash), gv_stashpv("doubly", GV_ADD));
}

/* ============================================
   XS Functions
   ============================================ */

static XS(xs_new) {
    dXSARGS;
    IV list_idx;
    IV node_id;
    SV* data;
#ifdef USE_ITHREADS
    UV owner_tid;
#endif

    PERL_UNUSED_VAR(items);

    data = (items > 1) ? ST(1) : &PL_sv_undef;
    list_idx = new_list(aTHX_ data);
    node_id = list_head_node_id(list_idx);

#ifdef USE_ITHREADS
    owner_tid = PTR2UV(PERL_GET_THX);
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, node_id, owner_tid));
#else
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, node_id));
#endif
    XSRETURN(1);
}

static XS(xs_length) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;

    if (items < 1 || !SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV)
        croak("Usage: doubly::length(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;

    ST(0) = sv_2mortal(newSViv(list_length(list_idx)));
    XSRETURN(1);
}

static XS(xs_data) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;

    if (items < 1 || !SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV)
        croak("Usage: doubly::data(self, [value])");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;

    if (items > 1) {
        list_set_data_by_node_id(aTHX_ list_idx, node_id, ST(1));
    }

    ST(0) = sv_2mortal(list_data_by_node_id(aTHX_ list_idx, node_id));
    XSRETURN(1);
}

static XS(xs_start) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;
    IV node_id;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
#endif

    if (items < 1) croak("Usage: doubly::start(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = list_head_node_id(list_idx);

#ifdef USE_ITHREADS
    owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
    owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
#endif

    list_incref(list_idx);

#ifdef USE_ITHREADS
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, node_id, owner_tid));
#else
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, node_id));
#endif
    XSRETURN(1);
}

static XS(xs_end) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;
    IV node_id;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
#endif

    if (items < 1) croak("Usage: doubly::end(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = list_tail_node_id(list_idx);

#ifdef USE_ITHREADS
    owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
    owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
#endif

    list_incref(list_idx);

#ifdef USE_ITHREADS
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, node_id, owner_tid));
#else
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, node_id));
#endif
    XSRETURN(1);
}

static XS(xs_next) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;
    IV next_node_id;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
#endif

    if (items < 1) croak("Usage: doubly::next(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;
    next_node_id = list_next_node_id(list_idx, node_id);

    if (next_node_id == 0) {
        ST(0) = &PL_sv_undef;
    } else {
#ifdef USE_ITHREADS
        owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
        owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
#endif
        list_incref(list_idx);
#ifdef USE_ITHREADS
        ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, next_node_id, owner_tid));
#else
        ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, next_node_id));
#endif
    }
    XSRETURN(1);
}

static XS(xs_prev) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;
    IV prev_node_id;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
#endif

    if (items < 1) croak("Usage: doubly::prev(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;
    prev_node_id = list_prev_node_id(list_idx, node_id);

    if (prev_node_id == 0) {
        ST(0) = &PL_sv_undef;
    } else {
#ifdef USE_ITHREADS
        owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
        owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
#endif
        list_incref(list_idx);
#ifdef USE_ITHREADS
        ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, prev_node_id, owner_tid));
#else
        ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, prev_node_id));
#endif
    }
    XSRETURN(1);
}

static XS(xs_is_start) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;

    if (items < 1) croak("Usage: doubly::is_start(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;

    ST(0) = boolSV(list_is_start_node(list_idx, node_id));
    XSRETURN(1);
}

static XS(xs_is_end) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;

    if (items < 1) croak("Usage: doubly::is_end(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;

    ST(0) = boolSV(list_is_end_node(list_idx, node_id));
    XSRETURN(1);
}

static XS(xs_add) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;

    if (items < 2) croak("Usage: doubly::add(self, data)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;

    list_add(aTHX_ list_idx, ST(1));

    /* If current node_id is 0, update to tail */
    if (node_id == 0) {
        hv_store(hash, "_node_id", 8, newSViv(list_tail_node_id(list_idx)), 0);
    }

    /* Return $self for chaining - no refcount increment needed */
    XSRETURN(1);
}

static XS(xs_bulk_add) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;
    int i;

    if (items < 1) croak("Usage: doubly::bulk_add(self, ...)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;

    for (i = 1; i < items; i++) {
        list_add(aTHX_ list_idx, ST(i));
    }

    /* Return $self for chaining - no refcount increment needed */
    XSRETURN(1);
}

static XS(xs_remove_from_start) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;
    IV old_head_id;
    IV new_head_id;
    SV* result;

    if (items < 1) croak("Usage: doubly::remove_from_start(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;
    old_head_id = list_head_node_id(list_idx);

    result = list_remove_from_start(aTHX_ list_idx);

    /* If we were pointing to old head, update to new head */
    if (node_id == old_head_id) {
        new_head_id = list_head_node_id(list_idx);
        hv_store(hash, "_node_id", 8, newSViv(new_head_id), 0);
    }

    ST(0) = sv_2mortal(result);
    XSRETURN(1);
}

static XS(xs_remove_from_end) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;
    IV old_tail_id;
    IV new_tail_id;
    SV* result;

    if (items < 1) croak("Usage: doubly::remove_from_end(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;
    old_tail_id = list_tail_node_id(list_idx);

    result = list_remove_from_end(aTHX_ list_idx);

    /* If we were pointing to old tail, update to new tail */
    if (node_id == old_tail_id) {
        new_tail_id = list_tail_node_id(list_idx);
        hv_store(hash, "_node_id", 8, newSViv(new_tail_id), 0);
    }

    ST(0) = sv_2mortal(result);
    XSRETURN(1);
}

static XS(xs_remove) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;
    RemoveResult result;

    if (items < 1) croak("Usage: doubly::remove(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;

    result = list_remove_by_node_id(aTHX_ list_idx, node_id);

    /* Update _node_id to next node */
    hv_store(hash, "_node_id", 8, newSViv(result.next_node_id), 0);

    ST(0) = sv_2mortal(result.data);
    XSRETURN(1);
}

static XS(xs_remove_from_pos) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;
    IV pos;
    SV* result;

    if (items < 2) croak("Usage: doubly::remove_from_pos(self, pos)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    pos = SvIV(ST(1));

    result = list_remove_at_pos(aTHX_ list_idx, pos);

    ST(0) = sv_2mortal(result);
    XSRETURN(1);
}

static XS(xs_insert_before) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;
    IV new_node_id;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
#endif

    if (items < 2) croak("Usage: doubly::insert_before(self, data)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;

    new_node_id = list_insert_before_node_id(aTHX_ list_idx, node_id, ST(1));

#ifdef USE_ITHREADS
    owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
    owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
#endif

    list_incref(list_idx);

#ifdef USE_ITHREADS
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, new_node_id, owner_tid));
#else
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, new_node_id));
#endif
    XSRETURN(1);
}

static XS(xs_insert_after) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    SV** node_id_sv;
    IV list_idx;
    IV node_id;
    IV new_node_id;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
#endif

    if (items < 2) croak("Usage: doubly::insert_after(self, data)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    node_id_sv = hv_fetch(hash, "_node_id", 8, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    node_id = node_id_sv ? SvIV(*node_id_sv) : 0;

    new_node_id = list_insert_after_node_id(aTHX_ list_idx, node_id, ST(1));

#ifdef USE_ITHREADS
    owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
    owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
#endif

    list_incref(list_idx);

#ifdef USE_ITHREADS
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, new_node_id, owner_tid));
#else
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, new_node_id));
#endif
    XSRETURN(1);
}

static XS(xs_insert_at_start) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;
    IV new_node_id;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
#endif

    if (items < 2) croak("Usage: doubly::insert_at_start(self, data)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;

    list_insert_at_start(aTHX_ list_idx, ST(1));
    new_node_id = list_head_node_id(list_idx);

#ifdef USE_ITHREADS
    owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
    owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
#endif

    list_incref(list_idx);

#ifdef USE_ITHREADS
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, new_node_id, owner_tid));
#else
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, new_node_id));
#endif
    XSRETURN(1);
}

static XS(xs_insert_at_end) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;
    IV new_node_id;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
#endif

    if (items < 2) croak("Usage: doubly::insert_at_end(self, data)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;

    list_insert_at_end(aTHX_ list_idx, ST(1));
    new_node_id = list_tail_node_id(list_idx);

#ifdef USE_ITHREADS
    owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
    owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
#endif

    list_incref(list_idx);

#ifdef USE_ITHREADS
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, new_node_id, owner_tid));
#else
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, new_node_id));
#endif
    XSRETURN(1);
}

static XS(xs_insert_at_pos) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;
    IV pos;
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_idx;
    IV new_node_id;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
#endif

    if (items < 3) croak("Usage: doubly::insert_at_pos(self, pos, data)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    pos = SvIV(ST(1));

    list_insert_at_pos(aTHX_ list_idx, pos, ST(2));

    /* Get the node_id of the inserted node (at pos) */
    DOUBLY_LOCK();
    list = get_list(list_idx);
    new_node_id = 0;
    if (list && !list->destroyed) {
        node_idx = get_node_at_pos(list, pos);
        if (node_idx >= 0) {
            node = get_node(node_idx);
            if (node) {
                new_node_id = node->node_id;
            }
        }
    }
    DOUBLY_UNLOCK();

#ifdef USE_ITHREADS
    owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
    owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
#endif

    list_incref(list_idx);

#ifdef USE_ITHREADS
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, new_node_id, owner_tid));
#else
    ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, new_node_id));
#endif
    XSRETURN(1);
}

static XS(xs_find) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;
    SV* cb;
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_idx;
    SV* node_data;
    int found;
    IV found_node_id;
    IV current_node_id;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
#endif

    if (items < 2) croak("Usage: doubly::find(self, callback)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    cb = ST(1);

    found = 0;
    found_node_id = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && !list->destroyed && list->length > 0) {
        node_idx = list->head_idx;
        while (node_idx >= 0 && !found) {
            node = get_node(node_idx);
            if (!node) break;

            current_node_id = node->node_id;
            node_data = node->data ? newSVsv(node->data) : &PL_sv_undef;

            DOUBLY_UNLOCK();

            {
                dSP;
                PUSHMARK(SP);
                XPUSHs(sv_2mortal(node_data));
                PUTBACK;
                call_sv(cb, G_SCALAR);
                SPAGAIN;
                if (SvTRUE(*PL_stack_sp)) {
                    found = 1;
                    found_node_id = current_node_id;
                }
                POPs;
            }

            DOUBLY_LOCK();
            list = get_list(list_idx);
            if (!list || list->destroyed) break;

            if (!found) {
                /* Re-find node by ID since list may have changed during callback */
                node_idx = find_node_by_id(list, current_node_id);
                if (node_idx >= 0) {
                    node = get_node(node_idx);
                    if (node) {
                        node_idx = node->next_idx;
                    } else {
                        break;
                    }
                } else {
                    /* Node was removed during callback, try to continue from head */
                    break;
                }
            }
        }
    }
    DOUBLY_UNLOCK();

    if (found) {
#ifdef USE_ITHREADS
        owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
        owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : PTR2UV(PERL_GET_THX);
#endif
        list_incref(list_idx);
#ifdef USE_ITHREADS
        ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, found_node_id, owner_tid));
#else
        ST(0) = sv_2mortal(create_doubly_object(aTHX_ list_idx, found_node_id));
#endif
    } else {
        ST(0) = &PL_sv_undef;
    }
    XSRETURN(1);
}

static XS(xs_insert) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;
    SV* cb;
    SV* data;
    DoublyListMeta* list;
    DoublyNodeSlot* node;
    IV node_idx;
    IV current_node_id;
    SV* node_data;
    int found;
    IV pos;

    if (items < 3 || !SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV)
        croak("Usage: doubly::insert(self, callback, data)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;
    cb = ST(1);
    data = ST(2);

    found = 0;
    pos = 0;

    DOUBLY_LOCK();
    list = get_list(list_idx);
    if (list && !list->destroyed && list->length > 0) {
        node_idx = list->head_idx;
        while (node_idx >= 0 && !found) {
            node = get_node(node_idx);
            if (!node) break;

            current_node_id = node->node_id;
            node_data = node->data ? newSVsv(node->data) : &PL_sv_undef;

            DOUBLY_UNLOCK();

            {
                dSP;
                PUSHMARK(SP);
                XPUSHs(sv_2mortal(node_data));
                PUTBACK;
                call_sv(cb, G_SCALAR);
                SPAGAIN;
                if (SvTRUE(*PL_stack_sp)) {
                    found = 1;
                }
                POPs;
            }

            DOUBLY_LOCK();
            list = get_list(list_idx);
            if (!list || list->destroyed) break;

            if (!found) {
                /* Re-find node by ID since list may have changed during callback */
                node_idx = find_node_by_id(list, current_node_id);
                if (node_idx >= 0) {
                    node = get_node(node_idx);
                    if (node) {
                        node_idx = node->next_idx;
                        pos++;
                    } else {
                        break;
                    }
                } else {
                    /* Node was removed during callback */
                    break;
                }
            }
        }
    }
    DOUBLY_UNLOCK();

    if (found) {
        list_insert_at_pos(aTHX_ list_idx, pos, data);
    } else {
        list_add(aTHX_ list_idx, data);
    }

    /* Return $self for chaining - no refcount increment needed */
    XSRETURN(1);
}

static XS(xs_destroy) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;

    if (items < 1) croak("Usage: doubly::destroy(self)");

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;

    list_destroy(aTHX_ list_idx);
    XSRETURN_EMPTY;
}

static XS(xs_DESTROY) {
    dXSARGS;
    HV* hash;
    SV** id_sv;
    IV list_idx;
#ifdef USE_ITHREADS
    SV** owner_tid_sv;
    UV owner_tid;
    UV my_tid;
#endif

    PERL_UNUSED_VAR(items);

    /* Skip cleanup during global destruction */
    if (PL_dirty) {
        XSRETURN_EMPTY;
    }

    hash = (HV*)SvRV(ST(0));
    id_sv = hv_fetch(hash, "_id", 3, 0);
    list_idx = id_sv ? SvIV(*id_sv) : -1;

#ifdef USE_ITHREADS
    owner_tid_sv = hv_fetch(hash, "_owner_tid", 10, 0);
    owner_tid = owner_tid_sv ? SvUV(*owner_tid_sv) : 0;
    my_tid = PTR2UV(PERL_GET_THX);

    /* Always decrement refcount - list_decref handles SV ownership internally.
     * This prevents memory leaks from cloned objects that never get cleaned up. */
    list_decref(aTHX_ list_idx);
    (void)owner_tid; /* Suppress unused variable warning */
    (void)my_tid;
#else
    list_decref(aTHX_ list_idx);
#endif
    XSRETURN_EMPTY;
}

static XS(xs_CLONE_SKIP) {
    dXSARGS;
    PERL_UNUSED_VAR(items);
    /* Return 1 - do NOT clone doubly objects to new threads.
     * Each thread must create its own lists. Sharing lists across
     * threads is not supported. */
    XSRETURN_IV(1);
}

/* ============================================
   Boot
   ============================================ */

XS_EXTERNAL(boot_doubly) {
    dXSBOOTARGSXSAPIVERCHK;
    CV *method_cv;
    SV *ckobj;
    PERL_UNUSED_VAR(items);

    doubly_init(aTHX);

    /* Register custom OPs */
    XopENTRY_set(&doubly_data_get_xop, xop_name, "doubly_data_get");
    XopENTRY_set(&doubly_data_get_xop, xop_desc, "doubly data getter");
    Perl_custom_op_register(aTHX_ pp_doubly_data_get, &doubly_data_get_xop);

    XopENTRY_set(&doubly_data_set_xop, xop_name, "doubly_data_set");
    XopENTRY_set(&doubly_data_set_xop, xop_desc, "doubly data setter");
    Perl_custom_op_register(aTHX_ pp_doubly_data_set, &doubly_data_set_xop);

    XopENTRY_set(&doubly_length_xop, xop_name, "doubly_length");
    XopENTRY_set(&doubly_length_xop, xop_desc, "doubly length");
    Perl_custom_op_register(aTHX_ pp_doubly_length, &doubly_length_xop);

    XopENTRY_set(&doubly_next_xop, xop_name, "doubly_next");
    XopENTRY_set(&doubly_next_xop, xop_desc, "doubly next");
    Perl_custom_op_register(aTHX_ pp_doubly_next, &doubly_next_xop);

    XopENTRY_set(&doubly_prev_xop, xop_name, "doubly_prev");
    XopENTRY_set(&doubly_prev_xop, xop_desc, "doubly prev");
    Perl_custom_op_register(aTHX_ pp_doubly_prev, &doubly_prev_xop);

    XopENTRY_set(&doubly_start_xop, xop_name, "doubly_start");
    XopENTRY_set(&doubly_start_xop, xop_desc, "doubly start");
    Perl_custom_op_register(aTHX_ pp_doubly_start, &doubly_start_xop);

    XopENTRY_set(&doubly_end_xop, xop_name, "doubly_end");
    XopENTRY_set(&doubly_end_xop, xop_desc, "doubly end");
    Perl_custom_op_register(aTHX_ pp_doubly_end, &doubly_end_xop);

    XopENTRY_set(&doubly_is_start_xop, xop_name, "doubly_is_start");
    XopENTRY_set(&doubly_is_start_xop, xop_desc, "doubly is_start");
    Perl_custom_op_register(aTHX_ pp_doubly_is_start, &doubly_is_start_xop);

    XopENTRY_set(&doubly_is_end_xop, xop_name, "doubly_is_end");
    XopENTRY_set(&doubly_is_end_xop, xop_desc, "doubly is_end");
    Perl_custom_op_register(aTHX_ pp_doubly_is_end, &doubly_is_end_xop);

    /* Register XS functions */
    newXS("doubly::new", xs_new, __FILE__);
    newXS("doubly::add", xs_add, __FILE__);
    newXS("doubly::bulk_add", xs_bulk_add, __FILE__);
    newXS("doubly::remove_from_start", xs_remove_from_start, __FILE__);
    newXS("doubly::remove_from_end", xs_remove_from_end, __FILE__);
    newXS("doubly::remove", xs_remove, __FILE__);
    newXS("doubly::remove_from_pos", xs_remove_from_pos, __FILE__);
    newXS("doubly::insert_before", xs_insert_before, __FILE__);
    newXS("doubly::insert_after", xs_insert_after, __FILE__);
    newXS("doubly::insert_at_start", xs_insert_at_start, __FILE__);
    newXS("doubly::insert_at_end", xs_insert_at_end, __FILE__);
    newXS("doubly::insert_at_pos", xs_insert_at_pos, __FILE__);
    newXS("doubly::find", xs_find, __FILE__);
    newXS("doubly::insert", xs_insert, __FILE__);
    newXS("doubly::destroy", xs_destroy, __FILE__);
    newXS("doubly::DESTROY", xs_DESTROY, __FILE__);
    newXS("doubly::CLONE_SKIP", xs_CLONE_SKIP, __FILE__);

    /* Register XS functions with call checkers for hot paths */

    /* data() - special checker handles both get and set */
    method_cv = newXS("doubly::data", xs_data, __FILE__);
    ckobj = newSViv(0);  /* Not used, checker handles both cases */
    cv_set_call_checker(method_cv, doubly_data_call_checker, ckobj);

    /* length() - 1 arg */
    method_cv = newXS("doubly::length", xs_length, __FILE__);
    ckobj = newSViv(PTR2IV(pp_doubly_length));
    cv_set_call_checker(method_cv, doubly_call_checker_1arg, ckobj);

    /* next() - 1 arg */
    method_cv = newXS("doubly::next", xs_next, __FILE__);
    ckobj = newSViv(PTR2IV(pp_doubly_next));
    cv_set_call_checker(method_cv, doubly_call_checker_1arg, ckobj);

    /* prev() - 1 arg */
    method_cv = newXS("doubly::prev", xs_prev, __FILE__);
    ckobj = newSViv(PTR2IV(pp_doubly_prev));
    cv_set_call_checker(method_cv, doubly_call_checker_1arg, ckobj);

    /* start() - 1 arg */
    method_cv = newXS("doubly::start", xs_start, __FILE__);
    ckobj = newSViv(PTR2IV(pp_doubly_start));
    cv_set_call_checker(method_cv, doubly_call_checker_1arg, ckobj);

    /* end() - 1 arg */
    method_cv = newXS("doubly::end", xs_end, __FILE__);
    ckobj = newSViv(PTR2IV(pp_doubly_end));
    cv_set_call_checker(method_cv, doubly_call_checker_1arg, ckobj);

    /* is_start() - 1 arg */
    method_cv = newXS("doubly::is_start", xs_is_start, __FILE__);
    ckobj = newSViv(PTR2IV(pp_doubly_is_start));
    cv_set_call_checker(method_cv, doubly_call_checker_1arg, ckobj);

    /* is_end() - 1 arg */
    method_cv = newXS("doubly::is_end", xs_is_end, __FILE__);
    ckobj = newSViv(PTR2IV(pp_doubly_is_end));
    cv_set_call_checker(method_cv, doubly_call_checker_1arg, ckobj);

    Perl_xs_boot_epilog(aTHX_ ax);
}
