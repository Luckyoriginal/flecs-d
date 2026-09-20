module flecs.c;

extern(C) @nogc nothrow:

// ============================================================================
// Core Types and Aliases
// ============================================================================

alias ecs_id_t = ulong;
alias ecs_entity_t = ecs_id_t;
alias ecs_size_t = int;
alias ecs_flags8_t = ubyte;
alias ecs_flags16_t = ushort;
alias ecs_flags32_t = uint;
alias ecs_flags64_t = ulong;
alias ecs_termset_t = uint;
alias ecs_ftime_t = float;

enum FLECS_TERM_COUNT_MAX = 32;

// ============================================================================
// Constants and Entity Flags
// ============================================================================

enum ECS_ROW_MASK            = 0x0FFFFFFFu;
enum ECS_ROW_FLAGS_MASK      = ~ECS_ROW_MASK;
enum ECS_ID_FLAGS_MASK       = 0xFFUL << 60;
enum ECS_ENTITY_MASK         = 0xFFFFFFFFUL;
enum ECS_GENERATION_MASK     = 0xFFFFUL << 32;
enum ECS_COMPONENT_MASK      = ~ECS_ID_FLAGS_MASK;

// Exported ID flags
extern const ecs_id_t ECS_PAIR;
extern const ecs_id_t ECS_AUTO_OVERRIDE;
extern const ecs_id_t ECS_TOGGLE;
extern const ecs_id_t ECS_VALUE_PAIR;

// Builtin entities and relationships
extern const ecs_entity_t EcsWildcard;
extern const ecs_entity_t EcsAny;
extern const ecs_entity_t EcsThis;
extern const ecs_entity_t EcsVariable;
extern const ecs_entity_t EcsTransitive;
extern const ecs_entity_t EcsReflexive;
extern const ecs_entity_t EcsFinal;
extern const ecs_entity_t EcsInheritable;
extern const ecs_entity_t EcsOnInstantiate;
extern const ecs_entity_t EcsOverride;
extern const ecs_entity_t EcsInherit;
extern const ecs_entity_t EcsDontInherit;
extern const ecs_entity_t EcsSymmetric;
extern const ecs_entity_t EcsExclusive;
extern const ecs_entity_t EcsAcyclic;
extern const ecs_entity_t EcsTraversable;
extern const ecs_entity_t EcsWith;
extern const ecs_entity_t EcsOneOf;
extern const ecs_entity_t EcsCanToggle;

extern const ecs_entity_t EcsChildOf;
extern const ecs_entity_t EcsIsA;
extern const ecs_entity_t EcsDependsOn;
extern const ecs_entity_t EcsSlotOf;
extern const ecs_entity_t EcsModule;
extern const ecs_entity_t EcsPrefab;
extern const ecs_entity_t EcsDisabled;
extern const ecs_entity_t EcsSingleton;
extern const ecs_entity_t EcsNotQueryable;

// Cleanup policies
extern const ecs_entity_t EcsOnDelete;
extern const ecs_entity_t EcsOnDeleteTarget;
extern const ecs_entity_t EcsRemove;
extern const ecs_entity_t EcsDelete;
extern const ecs_entity_t EcsPanic;

// Observer events
extern const ecs_entity_t EcsOnAdd;
extern const ecs_entity_t EcsOnRemove;
extern const ecs_entity_t EcsOnSet;
extern const ecs_entity_t EcsMonitor;
extern const ecs_entity_t EcsOnTableCreate;
extern const ecs_entity_t EcsOnTableDelete;
enum FLECS_EVENT_DESC_MAX = 8;

// Pipeline phases
extern const ecs_entity_t EcsOnStart;
extern const ecs_entity_t EcsPreFrame;
extern const ecs_entity_t EcsOnLoad;
extern const ecs_entity_t EcsPostLoad;
extern const ecs_entity_t EcsPreUpdate;
extern const ecs_entity_t EcsOnUpdate;
extern const ecs_entity_t EcsOnValidate;
extern const ecs_entity_t EcsPostUpdate;
extern const ecs_entity_t EcsPreStore;
extern const ecs_entity_t EcsOnStore;
extern const ecs_entity_t EcsPostFrame;
extern const ecs_entity_t EcsPhase;

// InOut flags for query terms
enum EcsInOutDefault = 0;
enum EcsInOutNone    = 1;
enum EcsInOut        = 2;
enum EcsIn           = 3;
enum EcsOut          = 4;

// Query operators
enum EcsAnd          = 0;
enum EcsOr           = 1;
enum EcsNot          = 2;
enum EcsOptional     = 3;
enum EcsAndFrom      = 4;
enum EcsOrFrom       = 5;
enum EcsNotFrom      = 6;

// Query caching kinds
enum ecs_query_cache_kind_t {
    EcsQueryCacheDefault = 0,
    EcsQueryCacheAuto,
    EcsQueryCacheAll,
    EcsQueryCacheNone
}

// ============================================================================
// Data Structures
// ============================================================================

struct ecs_world_t;
struct ecs_stage_t;
struct ecs_table_t;
struct ecs_query_t;
struct ecs_observable_t;
struct ecs_table_record_t;
struct ecs_mixins_t;

struct ecs_type_t {
    ecs_id_t* array;
    int count;
}

struct ecs_header_t {
    int type;
    int refcount;
    ecs_mixins_t* mixins;
}

struct ecs_term_ref_t {
    ecs_entity_t id;
    const(char)* name;
}

struct ecs_term_t {
    ecs_id_t id;
    ecs_term_ref_t src;
    ecs_term_ref_t first;
    ecs_term_ref_t second;
    ecs_entity_t trav;
    short inout_;
    short oper;
    byte field_index;
    ecs_flags16_t flags_;
}

alias ecs_order_by_action_t = extern(C) int function(ecs_world_t* world, ecs_table_t* table, const(void)* ptr1, const(void)* ptr2);
alias ecs_sort_table_action_t = extern(C) int function(ecs_world_t* world, ecs_table_t* table, const(ecs_entity_t)* entities, const(void)* ptr);
alias ecs_group_by_action_t = extern(C) ulong function(ecs_world_t* world, ecs_table_t* table, ecs_id_t id, void* ctx);
alias ecs_group_create_action_t = extern(C) void* function(ecs_world_t* world, ulong group_id, void* group_by_ctx);
alias ecs_group_delete_action_t = extern(C) void function(ecs_world_t* world, ulong group_id, void* group_ctx, void* group_by_ctx);
alias ecs_ctx_free_t = extern(C) void function(void* ctx);

struct ecs_query_desc_t {
    int _canary;
    ecs_term_t[FLECS_TERM_COUNT_MAX] terms;
    const(char)* expr;
    ecs_query_cache_kind_t cache_kind;
    ecs_flags32_t flags;
    ecs_order_by_action_t order_by_callback;
    ecs_sort_table_action_t order_by_table_callback;
    ecs_entity_t order_by;
    ecs_id_t group_by;
    ecs_group_by_action_t group_by_callback;
    ecs_group_create_action_t on_group_create;
    ecs_group_delete_action_t on_group_delete;
    void* group_by_ctx;
    ecs_ctx_free_t group_by_ctx_free;
    void* ctx;
    void* binding_ctx;
    ecs_ctx_free_t ctx_free;
    ecs_ctx_free_t binding_ctx_free;
    ecs_entity_t entity;
}

alias ecs_iter_action_t = extern(C) void function(ecs_iter_t* it);
alias ecs_run_action_t = extern(C) void function(ecs_iter_t* it);
alias ecs_iter_next_action_t = extern(C) bool function(ecs_iter_t* it);
alias ecs_iter_fini_action_t = extern(C) void function(ecs_iter_t* it);

struct ecs_iter_t {
    ecs_world_t* world;
    ecs_world_t* real_world;

    int offset;
    int count;
    const(ecs_entity_t)* entities;
    void** ptrs;
    const(ecs_table_record_t)** trs;
    const(ecs_size_t)* sizes;
    ecs_table_t* table;
    ecs_table_t* other_table;
    ecs_id_t* ids;
    ecs_entity_t* sources;
    ecs_flags64_t constrained_vars;
    ecs_termset_t set_fields;
    ecs_termset_t ref_fields;
    ecs_termset_t row_fields;
    ecs_termset_t up_fields;

    ecs_entity_t system;
    ecs_entity_t event;
    ecs_id_t event_id;
    int event_cur;

    byte field_count;
    byte term_index;
    const(ecs_query_t)* query;

    void* param;
    void* ctx;
    void* binding_ctx;
    void* callback_ctx;
    void* run_ctx;

    // Note: Initialize floats to 0.0f to prevent D's float.nan default initialization
    ecs_ftime_t delta_time = 0.0f;
    ecs_ftime_t delta_system_time = 0.0f;

    int frame_offset;

    ecs_flags32_t flags;
    ecs_entity_t interrupted_by;
    enum ECS_ITER_PRIV_SIZE = (size_t.sizeof == 8) ? 112 : 56;
    byte[ECS_ITER_PRIV_SIZE] priv_;

    ecs_iter_next_action_t next;
    ecs_iter_action_t callback;
    ecs_iter_fini_action_t fini;
    ecs_iter_t* chain_it;
}

struct ecs_system_desc_t {
    int _canary;
    ecs_entity_t entity;
    ecs_query_desc_t query;
    ecs_iter_action_t callback;
    ecs_run_action_t run;
    void* ctx;
    ecs_ctx_free_t ctx_free;
    void* callback_ctx;
    ecs_ctx_free_t callback_ctx_free;
    void* run_ctx;
    ecs_ctx_free_t run_ctx_free;
    ecs_ftime_t interval = 0.0f;
    int rate;
    ecs_entity_t tick_source;
    bool multi_threaded;
    bool immediate;
}

struct ecs_system_t {
    ecs_header_t hdr;
    ecs_run_action_t run;
    ecs_iter_action_t action;
    ecs_query_t* query;
    ecs_entity_t tick_source;
    bool multi_threaded;
    bool immediate;
    const(char)* name;
    void* ctx;
    void* callback_ctx;
    void* run_ctx;
}

struct ecs_observer_desc_t {
    int _canary;
    ecs_entity_t entity;
    ecs_query_desc_t query;
    ecs_entity_t[FLECS_EVENT_DESC_MAX] events;
    bool yield_existing;
    bool global_observer;
    ecs_iter_action_t callback;
    ecs_run_action_t run;
    void* ctx;
    ecs_ctx_free_t ctx_free;
    void* callback_ctx;
    ecs_ctx_free_t callback_ctx_free;
    void* run_ctx;
    ecs_ctx_free_t run_ctx_free;
    int* last_event_id;
    byte term_index_;
    ecs_flags32_t flags_;
}

struct ecs_observer_t {
    ecs_header_t hdr;
    ecs_query_t* query;
    ecs_entity_t[FLECS_EVENT_DESC_MAX] events;
    int event_count;
    ecs_iter_action_t callback;
    ecs_run_action_t run;
    void* ctx;
    void* callback_ctx;
    void* run_ctx;
    ecs_ctx_free_t ctx_free;
    ecs_ctx_free_t callback_ctx_free;
    ecs_ctx_free_t run_ctx_free;
    ecs_observable_t* observable;
    ecs_world_t* world;
    ecs_entity_t entity;
}

struct ecs_value_t {
    ecs_entity_t type;
    void* ptr;
}

struct ecs_entity_desc_t {
    int _canary;
    ecs_entity_t id;
    ecs_entity_t parent;
    const(char)* name;
    const(char)* sep;
    const(char)* root_sep;
    const(char)* symbol;
    bool use_low_id;
    const(ecs_id_t)* add;
    const(ecs_value_t)* set;
    const(char)* add_expr;
}

alias ecs_xtor_t = extern(C) void function(void* ptr, int count, const(ecs_type_info_t)* type_info);
alias ecs_copy_t = extern(C) void function(void* dst, const(void)* src, int count, const(ecs_type_info_t)* type_info);
alias ecs_move_t = extern(C) void function(void* dst, void* src, int count, const(ecs_type_info_t)* type_info);
alias ecs_cmp_t = extern(C) int function(const(void)* ptr1, const(void)* ptr2, const(ecs_type_info_t)* type_info);
alias ecs_equals_t = extern(C) bool function(const(void)* ptr1, const(void)* ptr2, const(ecs_type_info_t)* type_info);

struct ecs_type_hooks_t {
    ecs_xtor_t ctor;
    ecs_xtor_t dtor;
    ecs_copy_t copy;
    ecs_move_t move;
    ecs_copy_t copy_ctor;
    ecs_move_t move_ctor;
    ecs_move_t ctor_move_dtor;
    ecs_move_t move_dtor;
    ecs_cmp_t cmp;
    ecs_equals_t equals;
    ecs_flags32_t flags;
    ecs_iter_action_t on_add;
    ecs_iter_action_t on_set;
    ecs_iter_action_t on_remove;
    ecs_iter_action_t on_replace;
    void* ctx;
    void* binding_ctx;
    void* lifecycle_ctx;
    ecs_ctx_free_t ctx_free;
    ecs_ctx_free_t binding_ctx_free;
    ecs_ctx_free_t lifecycle_ctx_free;
}

struct ecs_type_info_t {
    ecs_size_t size;
    ecs_size_t alignment;
    ecs_type_hooks_t hooks;
    ecs_entity_t component;
    const(char)* name;
}

struct ecs_component_desc_t {
    int _canary;
    ecs_entity_t entity;
    ecs_type_info_t type;
}

// ============================================================================
// Inline Utilities and Helper Macros
// ============================================================================

pragma(inline, true) {
    uint ecs_entity_t_lo(ecs_entity_t value) {
        return cast(uint) value;
    }

    uint ecs_entity_t_hi(ecs_entity_t value) {
        return cast(uint)(value >> 32);
    }

    ulong ecs_entity_t_comb(uint lo, uint hi) {
        return (cast(ulong)hi << 32) | cast(uint)lo;
    }

    ecs_id_t ecs_pair(ecs_entity_t rel, ecs_entity_t tgt) {
        return ECS_PAIR | ecs_entity_t_comb(cast(uint)tgt, cast(uint)rel);
    }

    bool ecs_is_pair(ecs_id_t id) {
        return ((id & ECS_ID_FLAGS_MASK) == ECS_PAIR) || ((id & ECS_ID_FLAGS_MASK) == ECS_VALUE_PAIR);
    }

    ecs_entity_t ecs_pair_first(ecs_world_t* world, ecs_id_t pair) {
        return ecs_get_alive(world, cast(uint)(pair >> 32));
    }

    ecs_entity_t ecs_pair_second(ecs_world_t* world, ecs_id_t pair) {
        return ecs_get_alive(world, cast(uint)pair);
    }

    ecs_id_t ecs_dependson(ecs_entity_t entity) {
        return ecs_pair(EcsDependsOn, entity);
    }

    T* ecs_field(T)(const(ecs_iter_t)* it, byte index) {
        return cast(T*) ecs_field_w_size(it, T.sizeof, index);
    }

    T* ecs_field_at(T)(const(ecs_iter_t)* it, byte index, int row) {
        return cast(T*) ecs_field_at_w_size(it, T.sizeof, index, row);
    }
}

// ============================================================================
// Core C API Functions
// ============================================================================

// World lifecycle
ecs_world_t* ecs_init();
ecs_world_t* ecs_init_w_args(int argc, char** argv);
int ecs_fini(ecs_world_t* world);
bool ecs_progress(ecs_world_t* world, ecs_ftime_t delta_time);
void ecs_quit(ecs_world_t* world);
bool ecs_should_quit(ecs_world_t* world);
void ecs_set_target_fps(ecs_world_t* world, ecs_ftime_t fps);

// Entities
ecs_entity_t ecs_entity_init(ecs_world_t* world, const(ecs_entity_desc_t)* desc);
ecs_entity_t ecs_new_id(ecs_world_t* world);
ecs_entity_t ecs_new_low_id(ecs_world_t* world);
ecs_entity_t ecs_new_w_id(ecs_world_t* world, ecs_id_t id);
void ecs_delete(ecs_world_t* world, ecs_entity_t entity);
void ecs_clear(ecs_world_t* world, ecs_entity_t entity);
bool ecs_is_alive(ecs_world_t* world, ecs_entity_t entity);
bool ecs_is_valid(ecs_world_t* world, ecs_entity_t entity);
ecs_entity_t ecs_get_alive(ecs_world_t* world, ecs_entity_t entity);
const(char)* ecs_get_name(ecs_world_t* world, ecs_entity_t entity);
ecs_entity_t ecs_set_name(ecs_world_t* world, ecs_entity_t entity, const(char)* name);
ecs_entity_t ecs_lookup(ecs_world_t* world, const(char)* path);
ecs_entity_t ecs_lookup_child(ecs_world_t* world, ecs_entity_t parent, const(char)* name);
ecs_entity_t ecs_get_target(ecs_world_t* world, ecs_entity_t entity, ecs_entity_t rel, int index);
ecs_entity_t ecs_get_parent(ecs_world_t* world, ecs_entity_t entity);
const(ecs_type_t)* ecs_get_type(const(ecs_world_t)* world, ecs_entity_t entity);
char* ecs_type_str(const(ecs_world_t)* world, const(ecs_type_t)* type);

// Components and Tags
ecs_entity_t ecs_component_init(ecs_world_t* world, const(ecs_component_desc_t)* desc);
void ecs_add_id(ecs_world_t* world, ecs_entity_t entity, ecs_id_t id);
void ecs_remove_id(ecs_world_t* world, ecs_entity_t entity, ecs_id_t id);
bool ecs_has_id(ecs_world_t* world, ecs_entity_t entity, ecs_id_t id);
bool ecs_owns_id(ecs_world_t* world, ecs_entity_t entity, ecs_id_t id);
const(void)* ecs_get_id(ecs_world_t* world, ecs_entity_t entity, ecs_id_t id);
void* ecs_get_mut_id(ecs_world_t* world, ecs_entity_t entity, ecs_id_t id);
void ecs_set_id(ecs_world_t* world, ecs_entity_t entity, ecs_id_t id, size_t size, const(void)* ptr);
void ecs_modified_id(ecs_world_t* world, ecs_entity_t entity, ecs_id_t id);

// Queries
ecs_query_t* ecs_query_init(ecs_world_t* world, const(ecs_query_desc_t)* desc);
void ecs_query_fini(ecs_query_t* query);
ecs_iter_t ecs_query_iter(ecs_world_t* world, const(ecs_query_t)* query);
bool ecs_query_next(ecs_iter_t* it);
bool ecs_iter_next(ecs_iter_t* it);
void ecs_iter_fini(ecs_iter_t* it);

// Field accessors
void* ecs_field_w_size(const(ecs_iter_t)* it, size_t size, byte index);
void* ecs_field_at_w_size(const(ecs_iter_t)* it, size_t size, byte index, int row);
bool ecs_field_is_set(const(ecs_iter_t)* it, byte index);
bool ecs_field_is_readonly(const(ecs_iter_t)* it, byte index);
ecs_entity_t ecs_field_src(const(ecs_iter_t)* it, byte index);
ecs_id_t ecs_field_id(const(ecs_iter_t)* it, byte index);

// Systems
ecs_entity_t ecs_system_init(ecs_world_t* world, const(ecs_system_desc_t)* desc);
const(ecs_system_t)* ecs_system_get(ecs_world_t* world, ecs_entity_t system);
ecs_entity_t ecs_run(ecs_world_t* world, ecs_entity_t system, ecs_ftime_t delta_time, void* param);

// Observers
ecs_entity_t ecs_observer_init(ecs_world_t* world, const(ecs_observer_desc_t)* desc);
const(ecs_observer_t)* ecs_observer_get(const(ecs_world_t)* world, ecs_entity_t observer);

// Component Lifecycle Hooks
void ecs_set_hooks_id(ecs_world_t* world, ecs_entity_t component, const(ecs_type_hooks_t)* hooks);
const(ecs_type_hooks_t)* ecs_get_hooks_id(const(ecs_world_t)* world, ecs_entity_t component);

// Names & Paths
char* ecs_get_path_w_sep(const(ecs_world_t)* world, ecs_entity_t parent, ecs_entity_t child, const(char)* sep, const(char)* prefix);
ecs_entity_t ecs_lookup_path_w_sep(const(ecs_world_t)* world, ecs_entity_t parent, const(char)* path, const(char)* sep, const(char)* prefix, bool recursive);

// Entity Enabling / Disabling
void ecs_enable(ecs_world_t* world, ecs_entity_t entity, bool enabled);
void ecs_enable_id(ecs_world_t* world, ecs_entity_t entity, ecs_id_t component, bool enable);
bool ecs_is_enabled_id(const(ecs_world_t)* world, ecs_entity_t entity, ecs_id_t component);

// Clones, Counts, Deletions
ecs_entity_t ecs_clone(ecs_world_t* world, ecs_entity_t dst, ecs_entity_t src, bool copy_value);
void ecs_delete_with(ecs_world_t* world, ecs_id_t component);
int ecs_count_id(const(ecs_world_t)* world, ecs_id_t entity);

// Deferral
bool ecs_defer_begin(ecs_world_t* world);
bool ecs_defer_end(ecs_world_t* world);
void ecs_defer_suspend(ecs_world_t* world);
void ecs_defer_resume(ecs_world_t* world);
bool ecs_is_deferred(const(ecs_world_t)* world);

// Threading & Stages
void ecs_set_threads(ecs_world_t* world, int threads);
ecs_world_t* ecs_get_stage(const(ecs_world_t)* world, int stage_id);
int ecs_get_stage_count(const(ecs_world_t)* world);
int ecs_get_stage_id(const(ecs_world_t)* world);
bool ecs_is_stage(const(ecs_world_t)* world);
bool ecs_is_readonly(const(ecs_world_t)* world);
void ecs_set_automerge(ecs_world_t* world, bool auto_merge);

// Memory & OS API
alias ecs_os_api_free_t = extern(C) void function(void* ptr);
struct ecs_os_api_t {
    void* init_;
    void* fini_;
    void* malloc_;
    void* realloc_;
    void* calloc_;
    ecs_os_api_free_t free_;
}
extern __gshared ecs_os_api_t ecs_os_api;

pragma(inline, true) void ecs_os_free(void* ptr) {
    if (ecs_os_api.free_ !is null && ptr !is null) {
        ecs_os_api.free_(ptr);
    }
}
