module flecs;

public import flecs.c;

// ============================================================================
// Component Registration Metaprogramming
// ============================================================================

template ComponentId(T) {
    __gshared ecs_entity_t id = 0;
}

/**
 * Returns the cached Flecs component entity ID for type T,
 * automatically registering the component in the world on first access.
 */
ecs_entity_t componentId(T)(ecs_world_t* world) {
    alias CleanT = Unqual!T;
    if (ComponentId!CleanT.id == 0) {
        ecs_component_desc_t desc;
        ecs_entity_desc_t edesc;
        enum nameStr = CleanT.stringof ~ "\0";
        edesc.name = nameStr.ptr;
        edesc.symbol = nameStr.ptr;
        edesc.use_low_id = true;
        desc.entity = ecs_entity_init(world, &edesc);
        desc.type.size = cast(ecs_size_t) CleanT.sizeof;
        desc.type.alignment = cast(ecs_size_t) CleanT.alignof;
        ComponentId!CleanT.id = ecs_component_init(world, &desc);
    }
    return ComponentId!CleanT.id;
}

private template Unqual(T) {
    static if (is(T U == const U)) alias Unqual = U;
    else static if (is(T U == immutable U)) alias Unqual = U;
    else alias Unqual = T;
}

pragma(inline, true)
ref Comp getFieldOrInit(Comp)(void* ptr, ref Comp dummy) @nogc nothrow {
    if (ptr !is null) return *(cast(Comp*) ptr);
    dummy = Comp.init;
    return dummy;
}

// ============================================================================
// High-Level Entity Struct
// ============================================================================

struct Entity {
    ecs_world_t* world;
    ecs_entity_t id;

    // Implicit conversion to ecs_entity_t so it can be passed to any C function
    alias id this;

    @nogc nothrow:

    const(char)* name() const {
        return ecs_get_name(cast(ecs_world_t*)world, id);
    }

    ref Entity set_name(const(char)* n) return {
        ecs_set_name(world, id, n);
        return this;
    }

    char* path(const(char)* sep = ".", const(char)* prefix = null) const {
        return ecs_get_path_w_sep(cast(ecs_world_t*)world, 0, id, sep, prefix);
    }

    ref Entity set(T)(T value) return {
        ecs_entity_t cid = componentId!T(world);
        ecs_set_id(world, id, cid, T.sizeof, &value);
        return this;
    }

    const(T)* get(T)() const {
        ecs_entity_t cid = componentId!T(cast(ecs_world_t*)world);
        return cast(const(T)*) ecs_get_id(cast(ecs_world_t*)world, id, cid);
    }

    T* get_mut(T)() {
        ecs_entity_t cid = componentId!T(world);
        return cast(T*) ecs_get_mut_id(world, id, cid);
    }

    bool has(T)() const {
        ecs_entity_t cid = componentId!T(cast(ecs_world_t*)world);
        return ecs_has_id(cast(ecs_world_t*)world, id, cid);
    }

    ref Entity add(T)() return {
        ecs_entity_t cid = componentId!T(world);
        ecs_add_id(world, id, cid);
        return this;
    }

    ref Entity remove(T)() return {
        ecs_entity_t cid = componentId!T(world);
        ecs_remove_id(world, id, cid);
        return this;
    }

    ref Entity add_pair(ecs_entity_t rel, ecs_entity_t tgt) return {
        ecs_add_id(world, id, ecs_pair(rel, tgt));
        return this;
    }

    ref Entity add_pair(Rel)(ecs_entity_t tgt) return {
        return add_pair(componentId!Rel(world), tgt);
    }

    ref Entity remove_pair(ecs_entity_t rel, ecs_entity_t tgt) return {
        ecs_remove_id(world, id, ecs_pair(rel, tgt));
        return this;
    }

    ref Entity remove_pair(Rel)(ecs_entity_t tgt) return {
        return remove_pair(componentId!Rel(world), tgt);
    }

    bool has_pair(ecs_entity_t rel, ecs_entity_t tgt) const {
        return ecs_has_id(cast(ecs_world_t*)world, id, ecs_pair(rel, tgt));
    }

    bool has_pair(Rel)(ecs_entity_t tgt) const {
        return has_pair(componentId!Rel(cast(ecs_world_t*)world), tgt);
    }

    ref Entity child_of(ecs_entity_t parent) return {
        return add_pair(EcsChildOf, parent);
    }

    Entity target(ecs_entity_t rel, int index = 0) const {
        ecs_entity_t t = ecs_get_target(cast(ecs_world_t*)world, id, rel, index);
        return Entity(cast(ecs_world_t*)world, t);
    }

    Entity parent() const {
        ecs_entity_t p = ecs_get_parent(cast(ecs_world_t*)world, id);
        return Entity(cast(ecs_world_t*)world, p);
    }

    ref Entity is_a(ecs_entity_t prefab) return {
        return add_pair(EcsIsA, prefab);
    }

    ref Entity is_a(Entity prefab) return {
        return add_pair(EcsIsA, prefab.id);
    }

    ref Entity auto_override(T)() return {
        ecs_add_id(world, id, ECS_AUTO_OVERRIDE | componentId!T(world));
        return this;
    }

    ref Entity override_(T)() return {
        ecs_add_id(world, id, componentId!T(world));
        return this;
    }

    ref Entity enable() return {
        ecs_enable(world, id, true);
        return this;
    }

    ref Entity disable() return {
        ecs_enable(world, id, false);
        return this;
    }

    bool is_enabled() const {
        return !ecs_has_id(cast(ecs_world_t*)world, id, EcsDisabled);
    }

    ref Entity enable(T)() return {
        ecs_enable_id(world, id, componentId!T(world), true);
        return this;
    }

    ref Entity disable(T)() return {
        ecs_enable_id(world, id, componentId!T(world), false);
        return this;
    }

    bool is_enabled(T)() const {
        return ecs_is_enabled_id(cast(ecs_world_t*)world, id, componentId!T(cast(ecs_world_t*)world));
    }

    bool owns(T)() const {
        return ecs_owns_id(cast(ecs_world_t*)world, id, componentId!T(cast(ecs_world_t*)world));
    }

    bool owns_pair(ecs_entity_t rel, ecs_entity_t tgt) const {
        return ecs_owns_id(cast(ecs_world_t*)world, id, ecs_pair(rel, tgt));
    }

    Entity clone(bool copy_values = true) {
        ecs_entity_t cloned = ecs_clone(world, 0, id, copy_values);
        return Entity(world, cloned);
    }

    ref Entity modified(T)() return {
        ecs_modified_id(world, id, componentId!T(world));
        return this;
    }

    bool is_alive() const {
        return ecs_is_alive(cast(ecs_world_t*)world, id);
    }

    bool is_valid() const {
        return ecs_is_valid(cast(ecs_world_t*)world, id);
    }

    void destruct() {
        ecs_delete(world, id);
    }
}

// ============================================================================
// High-Level Iterator Struct
// ============================================================================

struct Iter {
    ecs_iter_t* handle;

    @nogc nothrow:

    int count() const {
        return handle.count;
    }

    ecs_ftime_t delta_time() const {
        return handle.delta_time;
    }

    ecs_world_t* world() {
        return handle.world;
    }

    Entity entity(int index) {
        return Entity(handle.world, handle.entities[index]);
    }

    T[] field(T)(byte index) {
        T* ptr = cast(T*) ecs_field_w_size(handle, T.sizeof, index);
        return ptr ? ptr[0 .. handle.count] : null;
    }
}

// ============================================================================
// High-Level Query Struct & Query Builder
// ============================================================================

struct Query(Components...) {
    ecs_world_t* world;
    ecs_query_t* query;

    static string callCodeWithEntity() {
        string s = "fn(e";
        static foreach (k; 0 .. Components.length) {
            s ~= ", (cast(Components[" ~ cast(char)('0' + k) ~ "]*)ptrs[" ~ cast(char)('0' + k) ~ "])[i]";
        }
        s ~= ");";
        return s;
    }

    static string callCodeWithoutEntity() {
        string s = "fn(";
        static foreach (k; 0 .. Components.length) {
            static if (k > 0) s ~= ", ";
            s ~= "(cast(Components[" ~ cast(char)('0' + k) ~ "]*)ptrs[" ~ cast(char)('0' + k) ~ "])[i]";
        }
        s ~= ");";
        return s;
    }

    /**
     * Iterate matching entities with a callback.
     * The callback can accept:
     *   (Entity e, ref C1 c1, ref C2 c2, ...)
     * or
     *   (ref C1 c1, ref C2 c2, ...)
     * or
     *   (Entity e) (when no components)
     */
    void each(Func)(Func fn) {
        ecs_iter_t it = ecs_query_iter(world, query);
        while (ecs_query_next(&it)) {
            void*[Components.length] ptrs;
            static foreach (idx, Comp; Components) {
                ptrs[idx] = ecs_field_w_size(&it, Comp.sizeof, cast(byte)idx);
            }
            for (int i = 0; i < it.count; ++i) {
                Entity e = Entity(world, it.entities[i]);
                static if (Components.length == 0) {
                    static if (__traits(compiles, { fn(e); })) {
                        fn(e);
                    } else static if (__traits(compiles, { fn(); })) {
                        fn();
                    } else {
                        static assert(0, "Incompatible callback for empty Query");
                    }
                } else {
                    static if (__traits(compiles, { mixin(callCodeWithEntity()); })) {
                        mixin(callCodeWithEntity());
                    } else static if (__traits(compiles, { mixin(callCodeWithoutEntity()); })) {
                        mixin(callCodeWithoutEntity());
                    } else {
                        static assert(0, "Incompatible callback signature for Query!(" ~ Components.stringof ~ ")");
                    }
                }
            }
        }
    }

    void destroy() {
        if (query) {
            ecs_query_fini(query);
            query = null;
        }
    }
}

struct QueryBuilder(Components...) {
    ecs_world_t* world;
    ecs_query_desc_t desc;

    QueryBuilder!Components expr(const(char)* e) {
        desc.expr = e;
        return this;
    }

    QueryBuilder!Components cache_kind(ecs_query_cache_kind_t k) {
        desc.cache_kind = k;
        return this;
    }

    Query!Components build() {
        static foreach (idx, Comp; Components) {
            desc.terms[idx].id = componentId!Comp(world);
        }
        return Query!Components(world, ecs_query_init(world, &desc));
    }
}

// ============================================================================
// High-Level System Structs
// ============================================================================

struct System(Components...) {
    ecs_world_t* world;
    ecs_entity_t id;

    alias id this;

    @nogc nothrow:

    void run(ecs_ftime_t dt = 0.0f) {
        ecs_run(world, id, dt, null);
    }

    void destruct() {
        ecs_delete(world, id);
    }
}

struct SystemBuilder(Components...) {
    ecs_world_t* world;
    const(char)* name;
    ecs_entity_t phase = 0;
    ecs_ftime_t interval_time = 0.0f;

    static string callWithEntity() {
        string s = "fn(e";
        static foreach (k; 0 .. Components.length) {
            s ~= ", (cast(Components[" ~ cast(char)('0' + k) ~ "]*)ptrs[" ~ cast(char)('0' + k) ~ "])[i]";
        }
        s ~= ");";
        return s;
    }

    static string callWithoutEntity() {
        string s = "fn(";
        static foreach (k; 0 .. Components.length) {
            static if (k > 0) s ~= ", ";
            s ~= "(cast(Components[" ~ cast(char)('0' + k) ~ "]*)ptrs[" ~ cast(char)('0' + k) ~ "])[i]";
        }
        s ~= ");";
        return s;
    }

    SystemBuilder!Components kind(ecs_entity_t p) {
        this.phase = p;
        return this;
    }

    SystemBuilder!Components interval(ecs_ftime_t seconds) {
        this.interval_time = seconds;
        return this;
    }

    /**
     * Finalize the system with an .each() callback.
     */
    System!Components each(Fn)(Fn fn) {
        alias UserFn = Fn;

        extern(C) static void sysCallback(ecs_iter_t* it) {
            void*[Components.length] ptrs;
            static foreach (idx, Comp; Components) {
                ptrs[idx] = ecs_field_w_size(it, Comp.sizeof, cast(byte)idx);
            }
            UserFn fn = cast(UserFn) it.ctx;
            for (int i = 0; i < it.count; ++i) {
                Entity e = Entity(it.world, it.entities[i]);
                static if (Components.length == 0) {
                    static if (__traits(compiles, { fn(e); })) {
                        fn(e);
                    } else static if (__traits(compiles, { fn(); })) {
                        fn();
                    }
                } else {
                    static if (__traits(compiles, { mixin(callWithEntity()); })) {
                        mixin(callWithEntity());
                    } else static if (__traits(compiles, { mixin(callWithoutEntity()); })) {
                        mixin(callWithoutEntity());
                    } else {
                        static assert(0, "Incompatible callback signature for system!(" ~ Components.stringof ~ ")");
                    }
                }
            }
        }

        ecs_system_desc_t sys_desc;
        ecs_entity_desc_t edesc;
        edesc.name = name;
        sys_desc.entity = ecs_entity_init(world, &edesc);
        sys_desc.interval = interval_time;

        static foreach (idx, Comp; Components) {
            sys_desc.query.terms[idx].id = componentId!Comp(world);
        }
        sys_desc.callback = &sysCallback;
        sys_desc.ctx = cast(void*) fn;

        ecs_entity_t sys_id = ecs_system_init(world, &sys_desc);
        ecs_entity_t targetPhase = (phase != 0) ? phase : EcsOnUpdate;
        if (targetPhase != 0) {
            ecs_id_t pair_id = ecs_pair(EcsDependsOn, targetPhase);
            ecs_add_id(world, sys_id, pair_id);
        }

        return System!Components(world, sys_id);
    }

    /**
     * Finalize the system with a raw runner callback taking (ref Iter it) or (ecs_iter_t* it).
     */
    System!Components run(RunFn)(RunFn fn) {
        alias UserRunFn = RunFn;

        extern(C) static void sysRun(ecs_iter_t* it) {
            UserRunFn fn = cast(UserRunFn) it.ctx;
            static if (__traits(compiles, { Iter iter = Iter(it); fn(iter); })) {
                Iter iter = Iter(it);
                fn(iter);
            } else static if (__traits(compiles, { fn(it); })) {
                fn(it);
            } else {
                static assert(0, "Incompatible run callback for system");
            }
        }

        ecs_system_desc_t sys_desc;
        ecs_entity_desc_t edesc;
        edesc.name = name;
        sys_desc.entity = ecs_entity_init(world, &edesc);
        sys_desc.interval = interval_time;

        static foreach (idx, Comp; Components) {
            sys_desc.query.terms[idx].id = componentId!Comp(world);
        }
        sys_desc.run = &sysRun;
        sys_desc.ctx = cast(void*) fn;

        ecs_entity_t sys_id = ecs_system_init(world, &sys_desc);
        ecs_entity_t targetPhase = (phase != 0) ? phase : EcsOnUpdate;
        if (targetPhase != 0) {
            ecs_id_t pair_id = ecs_pair(EcsDependsOn, targetPhase);
            ecs_add_id(world, sys_id, pair_id);
        }

        return System!Components(world, sys_id);
    }
}

// ============================================================================
// High-Level Observer Struct & Builder
// ============================================================================

struct Observer {
    ecs_world_t* world;
    ecs_entity_t id;

    alias id this;

    @nogc nothrow:

    void destruct() {
        if (world && id) {
            ecs_delete(world, id);
            id = 0;
        }
    }
}

struct ObserverBuilder(Components...) {
    ecs_world_t* world;
    const(char)* name;
    ecs_entity_t[FLECS_EVENT_DESC_MAX] events;
    int event_count = 0;
    bool yield_existing_flag = false;

    ObserverBuilder!Components event(ecs_entity_t evt) {
        if (event_count < FLECS_EVENT_DESC_MAX) {
            events[event_count++] = evt;
        }
        return this;
    }

    ObserverBuilder!Components yield_existing(bool val = true) {
        this.yield_existing_flag = val;
        return this;
    }

    static string callWithEntity() {
        string s = "fn(e";
        static foreach (k; 0 .. Components.length) {
            s ~= ", getFieldOrInit(ptrs[" ~ cast(char)('0' + k) ~ "], dummy_" ~ cast(char)('0' + k) ~ ")";
        }
        s ~= ");";
        return s;
    }

    static string callWithoutEntity() {
        string s = "fn(";
        static foreach (k; 0 .. Components.length) {
            static if (k > 0) s ~= ", ";
            s ~= "getFieldOrInit(ptrs[" ~ cast(char)('0' + k) ~ "], dummy_" ~ cast(char)('0' + k) ~ ")";
        }
        s ~= ");";
        return s;
    }

    Observer each(Fn)(Fn fn) {
        alias UserFn = Fn;

        extern(C) static void obsCallback(ecs_iter_t* it) {
            void*[Components.length] ptrs;
            static foreach (idx, Comp; Components) {
                ptrs[idx] = ecs_field_w_size(it, Comp.sizeof, cast(byte)idx);
            }
            UserFn fn = cast(UserFn) it.ctx;
            for (int i = 0; i < it.count; ++i) {
                Entity e = Entity(it.world, it.entities[i]);
                static foreach (k; 0 .. Components.length) {
                    mixin("Components[" ~ cast(char)('0' + k) ~ "] dummy_" ~ cast(char)('0' + k) ~ ";");
                }
                static if (Components.length == 0) {
                    static if (__traits(compiles, { fn(e); })) {
                        fn(e);
                    } else static if (__traits(compiles, { fn(); })) {
                        fn();
                    }
                } else {
                    static if (__traits(compiles, { mixin(callWithEntity()); })) {
                        mixin(callWithEntity());
                    } else static if (__traits(compiles, { mixin(callWithoutEntity()); })) {
                        mixin(callWithoutEntity());
                    } else {
                        static assert(0, "Incompatible callback signature for observer!(" ~ Components.stringof ~ ")");
                    }
                }
            }
        }

        ecs_observer_desc_t desc;
        ecs_entity_desc_t edesc;
        edesc.name = name;
        desc.entity = ecs_entity_init(world, &edesc);
        desc.yield_existing = yield_existing_flag;

        if (event_count == 0) {
            desc.events[0] = EcsOnSet;
        } else {
            for (int i = 0; i < event_count; ++i) {
                desc.events[i] = events[i];
            }
        }

        static foreach (idx, Comp; Components) {
            desc.query.terms[idx].id = componentId!Comp(world);
        }
        desc.callback = &obsCallback;
        desc.ctx = cast(void*) fn;

        ecs_entity_t obs_id = ecs_observer_init(world, &desc);
        return Observer(world, obs_id);
    }

    Observer run(RunFn)(RunFn fn) {
        alias UserRunFn = RunFn;

        extern(C) static void obsRun(ecs_iter_t* it) {
            UserRunFn fn = cast(UserRunFn) it.ctx;
            static if (__traits(compiles, { Iter iter = Iter(it); fn(iter); })) {
                Iter iter = Iter(it);
                fn(iter);
            } else static if (__traits(compiles, { fn(it); })) {
                fn(it);
            } else {
                static assert(0, "Incompatible run callback for observer");
            }
        }

        ecs_observer_desc_t desc;
        ecs_entity_desc_t edesc;
        edesc.name = name;
        desc.entity = ecs_entity_init(world, &edesc);
        desc.yield_existing = yield_existing_flag;

        if (event_count == 0) {
            desc.events[0] = EcsOnSet;
        } else {
            for (int i = 0; i < event_count; ++i) {
                desc.events[i] = events[i];
            }
        }

        static foreach (idx, Comp; Components) {
            desc.query.terms[idx].id = componentId!Comp(world);
        }
        desc.callback = &obsRun;
        desc.ctx = cast(void*) fn;

        ecs_entity_t obs_id = ecs_observer_init(world, &desc);
        return Observer(world, obs_id);
    }
}

// ============================================================================
// High-Level Component Lifecycle Hooks Builder
// ============================================================================

struct HooksBuilder(T) {
    ecs_world_t* world;
    ecs_type_hooks_t hooks;

    @nogc nothrow:

    HooksBuilder!T ctor(ecs_xtor_t fn) {
        hooks.ctor = fn;
        return this;
    }

    HooksBuilder!T dtor(ecs_xtor_t fn) {
        hooks.dtor = fn;
        return this;
    }

    HooksBuilder!T copy(ecs_copy_t fn) {
        hooks.copy = fn;
        return this;
    }

    HooksBuilder!T move(ecs_move_t fn) {
        hooks.move = fn;
        return this;
    }

    HooksBuilder!T on_add(ecs_iter_action_t fn) {
        hooks.on_add = fn;
        return this;
    }

    HooksBuilder!T on_set(ecs_iter_action_t fn) {
        hooks.on_set = fn;
        return this;
    }

    HooksBuilder!T on_remove(ecs_iter_action_t fn) {
        hooks.on_remove = fn;
        return this;
    }

    void build() {
        ecs_entity_t cid = componentId!T(world);
        ecs_set_hooks_id(world, cid, &hooks);
    }
}

// ============================================================================
// High-Level World Struct
// ============================================================================

struct World {
    ecs_world_t* handle;

    @nogc nothrow:

    static World create() {
        return World(ecs_init());
    }

    static World create(int argc, char** argv) {
        return World(ecs_init_w_args(argc, argv));
    }

    int destroy() {
        if (handle) {
            int ret = ecs_fini(handle);
            handle = null;
            return ret;
        }
        return 0;
    }

    bool progress(ecs_ftime_t dt = 0.0f) {
        return ecs_progress(handle, dt);
    }

    void quit() {
        ecs_quit(handle);
    }

    bool should_quit() const {
        return ecs_should_quit(cast(ecs_world_t*)handle);
    }

    void set_target_fps(ecs_ftime_t fps) {
        ecs_set_target_fps(handle, fps);
    }

    Entity entity(const(char)* name = null) {
        ecs_entity_desc_t desc;
        desc.name = name;
        return Entity(handle, ecs_entity_init(handle, &desc));
    }

    Entity prefab(const(char)* name = null) {
        ecs_entity_desc_t desc;
        desc.name = name;
        ecs_entity_t e = ecs_entity_init(handle, &desc);
        ecs_add_id(handle, e, EcsPrefab);
        return Entity(handle, e);
    }

    Entity lookup(const(char)* path) const {
        return Entity(cast(ecs_world_t*)handle, ecs_lookup(cast(ecs_world_t*)handle, path));
    }

    Entity lookup_child(ecs_entity_t parent, const(char)* name) const {
        return Entity(cast(ecs_world_t*)handle, ecs_lookup_child(cast(ecs_world_t*)handle, parent, name));
    }

    Entity lookup_child(Entity parent, const(char)* name) const {
        return Entity(cast(ecs_world_t*)handle, ecs_lookup_child(cast(ecs_world_t*)handle, parent.id, name));
    }

    ecs_entity_t component(T)(const(char)* name = null) {
        return componentId!T(handle);
    }

    ecs_entity_t id(T)() {
        return componentId!T(handle);
    }

    // Singletons
    ref World set(T)(T value) return {
        ecs_entity_t cid = componentId!T(handle);
        ecs_set_id(handle, cid, cid, T.sizeof, &value);
        return this;
    }

    const(T)* get(T)() const {
        ecs_entity_t cid = componentId!T(cast(ecs_world_t*)handle);
        return cast(const(T)*) ecs_get_id(cast(ecs_world_t*)handle, cid, cid);
    }

    T* get_mut(T)() {
        ecs_entity_t cid = componentId!T(handle);
        return cast(T*) ecs_get_mut_id(handle, cid, cid);
    }

    bool has(T)() const {
        ecs_entity_t cid = componentId!T(cast(ecs_world_t*)handle);
        return ecs_has_id(cast(ecs_world_t*)handle, cid, cid);
    }

    void remove(T)() {
        ecs_entity_t cid = componentId!T(handle);
        ecs_remove_id(handle, cid, cid);
    }

    void modified(T)() {
        ecs_entity_t cid = componentId!T(handle);
        ecs_modified_id(handle, cid, cid);
    }

    // Component Lifecycle Hooks
    HooksBuilder!T hooks(T)() {
        return HooksBuilder!T(handle);
    }

    void set_hooks(T)(const(ecs_type_hooks_t)* h) {
        ecs_entity_t cid = componentId!T(handle);
        ecs_set_hooks_id(handle, cid, h);
    }

    void set_hooks(T)(ecs_type_hooks_t h) {
        ecs_entity_t cid = componentId!T(handle);
        ecs_set_hooks_id(handle, cid, &h);
    }

    // Batch Entity Operations & Counts
    int count(T)() const {
        ecs_entity_t cid = componentId!T(cast(ecs_world_t*)handle);
        return ecs_count_id(cast(ecs_world_t*)handle, cid);
    }

    int count(ecs_id_t id) const {
        return ecs_count_id(cast(ecs_world_t*)handle, id);
    }

    void delete_with(T)() {
        ecs_entity_t cid = componentId!T(handle);
        ecs_delete_with(handle, cid);
    }

    void delete_with(ecs_id_t id) {
        ecs_delete_with(handle, id);
    }

    // Deferral
    bool defer_begin() {
        return ecs_defer_begin(handle);
    }

    bool defer_end() {
        return ecs_defer_end(handle);
    }

    void defer_suspend() {
        ecs_defer_suspend(handle);
    }

    void defer_resume() {
        ecs_defer_resume(handle);
    }

    bool is_deferred() const {
        return ecs_is_deferred(cast(ecs_world_t*)handle);
    }

    void defer(Fn)(scope Fn fn) {
        ecs_defer_begin(handle);
        fn();
        ecs_defer_end(handle);
    }

    // Threading & Stages
    void set_threads(int threads) {
        ecs_set_threads(handle, threads);
    }

    int stage_count() const {
        return ecs_get_stage_count(cast(ecs_world_t*)handle);
    }

    bool is_stage() const {
        return ecs_is_stage(cast(ecs_world_t*)handle);
    }

    bool is_readonly() const {
        return ecs_is_readonly(cast(ecs_world_t*)handle);
    }

    World get_stage(int stage_id) const {
        return World(ecs_get_stage(cast(ecs_world_t*)handle, stage_id));
    }

    // Queries & Filters
    Query!Components query(Components...)(const(char)* expr = null) {
        ecs_query_desc_t qdesc;
        qdesc.expr = expr;
        static foreach (idx, Comp; Components) {
            qdesc.terms[idx].id = componentId!Comp(handle);
        }
        return Query!Components(handle, ecs_query_init(handle, &qdesc));
    }

    Query!Components filter(Components...)(const(char)* expr = null) {
        ecs_query_desc_t qdesc;
        qdesc.cache_kind = ecs_query_cache_kind_t.EcsQueryCacheNone;
        qdesc.expr = expr;
        static foreach (idx, Comp; Components) {
            qdesc.terms[idx].id = componentId!Comp(handle);
        }
        return Query!Components(handle, ecs_query_init(handle, &qdesc));
    }

    QueryBuilder!Components query_builder(Components...)() {
        QueryBuilder!Components qb;
        qb.world = handle;
        return qb;
    }

    // Systems
    SystemBuilder!Components system(Components...)(const(char)* name = null, ecs_entity_t phase = 0) {
        return SystemBuilder!Components(handle, name, phase);
    }

    // Observers
    ObserverBuilder!Components observer(Components...)(const(char)* name = null) {
        return ObserverBuilder!Components(handle, name);
    }
}
