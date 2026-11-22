/* Godot binding for the navigation core. Calls cross this boundary in batches. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "gdextension_interface.h"
#include "mob_decide.h"
#include "mob_exec.h"
#include "mob_nav.h"
#include "mob_obs.h"
#include "mob_policy.h"
#include "mob_sense.h"

typedef struct { void *opaque; } StringNameStorage;
typedef struct { void *opaque; } StringStorage;
typedef struct { void *first; void *second; } PackedStorage;

typedef struct {
    MobNav *nav;
    MobObs *obs;
    MobPolicy *policy;
    MobExec *exec;
    MobDecide *decide;
    MobSense *sense;
} World;

typedef enum { KIND_INT, KIND_FLOAT, KIND_BYTES, KIND_FLOATS, KIND_ARRAY, KIND_COUNT } Kind;

#define MAX_ARGS 6

typedef void (*Implementation)(World *world, const void *const *args, void *result);

typedef struct {
    const char *name;
    Implementation run;
    Kind result;
    int argument_count;
    Kind kinds[MAX_ARGS];
    const char *arguments[MAX_ARGS];
} Method;

static GDExtensionClassLibraryPtr library;
static StringNameStorage world_name;
static StringNameStorage object_name;
static GDExtensionInterfaceStringNameNewWithUtf8Chars make_name;
static GDExtensionInterfaceStringNewWithUtf8Chars make_string;
static GDExtensionInterfaceClassdbConstructObject3 construct_object;
static GDExtensionInterfaceObjectSetInstance attach_instance;
static GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceClassdbGetMethodBind get_method;
static GDExtensionInterfaceObjectMethodBindPtrcall call_builtin;
static GDExtensionMethodBindPtr notify_method;
static GDExtensionInterfaceVariantGetType variant_type;
static GDExtensionInterfaceVariantDestroy destroy_variant;
static GDExtensionInterfacePackedByteArrayOperatorIndexConst bytes_at;
static GDExtensionInterfacePackedByteArrayOperatorIndex bytes_at_mutable;
static GDExtensionInterfacePackedFloat32ArrayOperatorIndex floats_at;
static GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst floats_at_const;
static GDExtensionInterfacePackedInt32ArrayOperatorIndexConst ints_at;
static GDExtensionInterfaceArrayOperatorIndexConst array_at;
static GDExtensionVariantGetInternalPtrFunc internal_ints;
static GDExtensionPtrBuiltInMethod ints_size;
static GDExtensionPtrBuiltInMethod array_size;
static GDExtensionPtrBuiltInMethod bytes_size;
static GDExtensionPtrBuiltInMethod floats_size;
static GDExtensionPtrBuiltInMethod floats_resize;
static GDExtensionPtrBuiltInMethod bytes_resize;
static GDExtensionPtrConstructor floats_construct;
static GDExtensionPtrDestructor floats_destroy;
static GDExtensionPtrConstructor bytes_construct;
static GDExtensionPtrDestructor bytes_destroy;
static GDExtensionPtrDestructor destroy_name;
static GDExtensionPtrDestructor destroy_string;
static GDExtensionVariantGetInternalPtrFunc internal_value[KIND_COUNT];
static GDExtensionVariantFromTypeConstructorFunc to_variant[KIND_COUNT];

static const GDExtensionVariantType variant_kinds[KIND_COUNT] = {
    GDEXTENSION_VARIANT_TYPE_INT,
    GDEXTENSION_VARIANT_TYPE_FLOAT,
    GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,
    GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,
    GDEXTENSION_VARIANT_TYPE_ARRAY,
};

static inline int64_t arg_int(const void *const *args, int index) { return *(const int64_t *)args[index]; }
static inline double arg_float(const void *const *args, int index) { return *(const double *)args[index]; }

static int64_t byte_count(const void *array) {
    int64_t count = 0;
    bytes_size((GDExtensionTypePtr)array, NULL, &count, 0);
    return count;
}

static int64_t float_count(const void *array) {
    int64_t count = 0;
    floats_size((GDExtensionTypePtr)array, NULL, &count, 0);
    return count;
}

static const float *float_data(const void *array) {
    return float_count(array) > 0 ? floats_at_const(array, 0) : NULL;
}

static void m_initialize(World *world, const void *const *args, void *result) {
    int64_t agents = arg_int(args, 0), targets = arg_int(args, 1);
    if (agents < 1 || agents > 4096 || targets < 1 || targets > 64) {
        *(int64_t *)result = MN_ERR_ARGUMENT;
        return;
    }
    MobNav *created = mn_create((int)agents, (int)targets);
    if (created == NULL) {
        *(int64_t *)result = MN_ERR_MEMORY;
        return;
    }
    mn_destroy(world->nav);
    mo_destroy(world->obs);
    mp_destroy(world->policy);
    me_destroy(world->exec);
    md_destroy(world->decide);
    ms_destroy(world->sense);
    world->nav = created;
    world->obs = NULL;
    world->policy = NULL;
    world->exec = NULL;
    world->decide = NULL;
    world->sense = NULL;
    *(int64_t *)result = MN_OK;
}

/* Reads an Array of packed arrays without copying them. */
static int read_items(const void *array, int expected, MoKind (*kind_of)(int), const void **items, int64_t *lengths) {
    int64_t count = 0;
    array_size((GDExtensionTypePtr)array, NULL, &count, 0);
    if (count != expected) return 0;
    for (int i = 0; i < expected; i++) {
        GDExtensionConstVariantPtr element = array_at(array, i);
        GDExtensionVariantType type = variant_type(element);
        int64_t length = 0;
        const void *data = NULL;
        MoKind kind = kind_of(i);
        if (kind == MO_BYTES && type == GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY) {
            const void *packed = internal_value[KIND_BYTES]((GDExtensionVariantPtr)element);
            length = byte_count(packed);
            data = length > 0 ? bytes_at(packed, 0) : NULL;
        } else if (kind == MO_FLOATS && type == GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY) {
            const void *packed = internal_value[KIND_FLOATS]((GDExtensionVariantPtr)element);
            length = float_count(packed);
            data = float_data(packed);
        } else if (kind == MO_INTS && type == GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY) {
            const void *packed = internal_ints((GDExtensionVariantPtr)element);
            ints_size((GDExtensionTypePtr)packed, NULL, &length, 0);
            data = length > 0 ? ints_at(packed, 0) : NULL;
        } else {
            return 0;
        }
        items[i] = data;
        lengths[i] = length;
    }
    return 1;
}

static void m_obs_configure(World *world, const void *const *args, void *result) {
    const void *items[MC_COUNT];
    int64_t lengths[MC_COUNT];
    if (!read_items(args[0], MC_COUNT, mo_config_kind, items, lengths)) {
        *(int64_t *)result = MO_ERR_ARGUMENT;
        return;
    }
    MobObs *created = NULL;
    MoResult status = mo_create(items, lengths, &created);
    if (status == MO_OK) {
        mo_destroy(world->obs);
        world->obs = created;
    }
    *(int64_t *)result = status;
}

static void m_obs_build(World *world, const void *const *args, void *result) {
    const void *items[MI_COUNT];
    int64_t lengths[MI_COUNT];
    int64_t values = 0, resized = 0;
    int ready = world->obs != NULL && world->nav != NULL && read_items(args[0], MI_COUNT, mo_input_kind, items, lengths);
    if (ready) values = lengths[MI_SLOTS] * mo_observation_size(world->obs);
    GDExtensionConstTypePtr resize_args[] = {&values};
    floats_resize(result, resize_args, &resized, 1);
    if (values > 0 && resized == 0 && mo_build(world->obs, world->nav, world->sense, items, lengths, floats_at(result, 0)) != MO_OK) {
        values = 0;
        floats_resize(result, resize_args, &resized, 1);
    }
}

/* Executor kinds share MoKind's numbering: bytes, ints, floats. */
static MoKind exec_config_kind(int index) { return (MoKind)me_config_kind(index); }
static MoKind exec_input_kind(int index) { return (MoKind)me_input_kind(index); }

static void m_exec_configure(World *world, const void *const *args, void *result) {
    const void *items[EC_COUNT];
    int64_t lengths[EC_COUNT];
    if (!read_items(args[0], EC_COUNT, exec_config_kind, items, lengths)) {
        *(int64_t *)result = ME_ERR_ARGUMENT;
        return;
    }
    MobExec *created = NULL;
    MeResult status = me_create(items, lengths, &created);
    if (status == ME_OK) {
        me_destroy(world->exec);
        world->exec = created;
    }
    *(int64_t *)result = status;
}

/* Returns commands, targets, the request count and the requests, or an empty array on bad input. */
static void m_exec_run(World *world, const void *const *args, void *result) {
    const void *items[EI_COUNT];
    int64_t lengths[EI_COUNT];
    int64_t values = 0, resized = 0;
    int ready = world->exec != NULL && world->nav != NULL && read_items(args[0], EI_COUNT, exec_input_kind, items, lengths);
    if (ready) values = me_output_size(world->exec);
    GDExtensionConstTypePtr resize_args[] = {&values};
    floats_resize(result, resize_args, &resized, 1);
    if (values > 0 && resized == 0 && me_run(world->exec, world->nav, world->sense, items, lengths, floats_at(result, 0)) != ME_OK) {
        values = 0;
        floats_resize(result, resize_args, &resized, 1);
    }
}

static MoKind decide_config_kind(int index) { return (MoKind)md_config_kind(index); }
static MoKind decide_input_kind(int index) { return (MoKind)md_input_kind(index); }

static void m_decide_configure(World *world, const void *const *args, void *result) {
    const void *items[DC_COUNT];
    int64_t lengths[DC_COUNT];
    if (!read_items(args[0], DC_COUNT, decide_config_kind, items, lengths)) {
        *(int64_t *)result = DK_ERR_ARGUMENT;
        return;
    }
    MobDecide *created = NULL;
    MdResult status = md_create(items, lengths, &created);
    if (status == DK_OK) {
        md_destroy(world->decide);
        world->decide = created;
    }
    *(int64_t *)result = status;
}

/* Shared by masks and the scripted brain: per_slot bytes for each due slot, or an empty array on bad input. */
static void run_decide(World *world, const void *const *args, void *result, int masks) {
    const void *items[DI_COUNT];
    int64_t lengths[DI_COUNT];
    int64_t values = 0, resized = 0;
    int ready = world->decide != NULL && read_items(args[0], DI_COUNT, decide_input_kind, items, lengths);
    if (ready) values = lengths[DI_SLOTS] * (masks ? md_mask_size(world->decide) : DK_HEAD_COUNT);
    GDExtensionConstTypePtr resize_args[] = {&values};
    bytes_resize(result, resize_args, &resized, 1);
    if (values <= 0 || resized != 0) return;
    MdResult status = masks ? md_masks(world->decide, items, lengths, bytes_at_mutable(result, 0))
                            : md_scripted(world->decide, items, lengths, bytes_at_mutable(result, 0));
    if (status != DK_OK) {
        values = 0;
        bytes_resize(result, resize_args, &resized, 1);
    }
}

static void m_decide_masks(World *world, const void *const *args, void *result) { run_decide(world, args, result, 1); }
static void m_decide_scripted(World *world, const void *const *args, void *result) { run_decide(world, args, result, 0); }

static MoKind sense_config_kind(int index) { return (MoKind)ms_config_kind(index); }
static MoKind sense_input_kind(int index) { return (MoKind)ms_input_kind(index); }

static void m_sense_configure(World *world, const void *const *args, void *result) {
    const void *items[SC_COUNT];
    int64_t lengths[SC_COUNT];
    if (!read_items(args[0], SC_COUNT, sense_config_kind, items, lengths)) {
        *(int64_t *)result = SK_ERR_ARGUMENT;
        return;
    }
    MobSense *created = NULL;
    MsResult status = ms_create(items, lengths, &created);
    if (status == SK_OK) {
        ms_destroy(world->sense);
        world->sense = created;
    }
    *(int64_t *)result = status;
}

/* Shared by the perception update and the ally refresh. Returns raw bytes, or an empty array on bad input. */
static void run_sense(World *world, const void *const *args, void *result, int allies) {
    const void *items[SI_COUNT];
    int64_t lengths[SI_COUNT];
    int64_t values = 0, resized = 0;
    int ready = world->sense != NULL && world->nav != NULL && read_items(args[0], SI_COUNT, sense_input_kind, items, lengths);
    if (ready) values = allies ? ms_allies_size(world->sense) : ms_update_size(world->sense);
    GDExtensionConstTypePtr resize_args[] = {&values};
    bytes_resize(result, resize_args, &resized, 1);
    if (values <= 0 || resized != 0) return;
    MsResult status = allies ? ms_allies(world->sense, world->nav, items, lengths, bytes_at_mutable(result, 0))
                             : ms_update(world->sense, world->nav, items, lengths, bytes_at_mutable(result, 0));
    if (status != SK_OK) {
        values = 0;
        bytes_resize(result, resize_args, &resized, 1);
    }
}

static void m_sense_update(World *world, const void *const *args, void *result) { run_sense(world, args, result, 0); }
static void m_sense_allies(World *world, const void *const *args, void *result) { run_sense(world, args, result, 1); }

static void m_sense_light_at(World *world, const void *const *args, void *result) {
    *(double *)result = world->sense != NULL ? ms_light_at(world->sense, (float)arg_float(args, 0), (float)arg_float(args, 1)) : 1.0;
}

static void m_sense_darkness_at(World *world, const void *const *args, void *result) {
    *(double *)result = world->sense != NULL ? ms_darkness_at(world->sense, (float)arg_float(args, 0), (float)arg_float(args, 1)) : 0.0;
}

static void m_sense_scent_at(World *world, const void *const *args, void *result) {
    *(double *)result = world->sense != NULL
        ? ms_scent_at(world->sense, (int)arg_int(args, 0), (float)arg_float(args, 1), (float)arg_float(args, 2)) : 0.0;
}

static MoKind speed_input_kind(int index) { return (MoKind)me_speed_input_kind(index); }

static void m_exec_speeds(World *world, const void *const *args, void *result) {
    const void *items[EV_COUNT];
    int64_t lengths[EV_COUNT];
    int64_t values = 0, resized = 0;
    int ready = world->exec != NULL && read_items(args[0], EV_COUNT, speed_input_kind, items, lengths);
    if (ready) values = me_output_size(world->exec) > 0 ? lengths[EV_COMMANDS] : 0;
    GDExtensionConstTypePtr resize_args[] = {&values};
    floats_resize(result, resize_args, &resized, 1);
    if (values > 0 && resized == 0 && me_speeds(world->exec, items, lengths, floats_at(result, 0)) != ME_OK) {
        values = 0;
        floats_resize(result, resize_args, &resized, 1);
    }
}

static void m_obs_reset_slot(World *world, const void *const *args, void *result) {
    mo_reset_slot(world->obs, (int)arg_int(args, 0));
    *(int64_t *)result = MO_OK;
}

static void m_policy_load(World *world, const void *const *args, void *result) {
    int64_t weights = byte_count(args[0]), hash = byte_count(args[1]), values = float_count(args[2]);
    const float *row = float_data(args[2]);
    MobPolicyLayout layout = {0};
    if (weights < 4 || hash != MP_HASH_LENGTH || values < 2 || row == NULL) {
        *(int64_t *)result = MP_ERR_ARGUMENT;
        return;
    }
    layout.observation_size = (int)row[0];
    layout.self_range_count = (int)row[1];
    if (layout.self_range_count < 1 || layout.self_range_count > MP_MAX_SELF_RANGES || values != 2 + 2 * layout.self_range_count + 11) {
        *(int64_t *)result = MP_ERR_ARGUMENT;
        return;
    }
    const float *cursor = row + 2;
    for (int i = 0; i < layout.self_range_count; i++) {
        layout.self_offset[i] = (int)*cursor++;
        layout.self_size[i] = (int)*cursor++;
    }
    layout.enemy_offset = (int)cursor[0];
    layout.enemy_stride = (int)cursor[1];
    layout.enemy_repeat = (int)cursor[2];
    layout.ally_offset = (int)cursor[3];
    layout.ally_stride = (int)cursor[4];
    layout.ally_repeat = (int)cursor[5];
    layout.leader_offset = (int)cursor[6];
    layout.leader_stride = (int)cursor[7];
    layout.logits = (int)cursor[8];
    layout.hidden = (int)cursor[9];
    layout.capacity = (int)cursor[10];
    MobPolicy *created = NULL;
    MpResult status = mp_load(bytes_at(args[0], 0), (size_t)weights, (const char *)bytes_at(args[1], 0), &layout, &created);
    if (status == MP_OK) {
        mp_destroy(world->policy);
        world->policy = created;
    }
    *(int64_t *)result = status;
}

/* Returns every row's logits followed by every row's next hidden state. */
static void m_policy_forward(World *world, const void *const *args, void *result) {
    int64_t obs_values = float_count(args[0]), hidden_values = float_count(args[1]), values = 0, resized = 0, rows = 0;
    if (world->policy != NULL && obs_values % mp_observation_size(world->policy) == 0) {
        rows = obs_values / mp_observation_size(world->policy);
        if (hidden_values == rows * mp_hidden(world->policy)) values = rows * (mp_logits(world->policy) + mp_hidden(world->policy));
    }
    GDExtensionConstTypePtr resize_args[] = {&values};
    floats_resize(result, resize_args, &resized, 1);
    if (values > 0 && resized == 0) {
        float *out = floats_at(result, 0);
        mp_forward(world->policy, float_data(args[0]), float_data(args[1]), (int)rows, out, out + rows * mp_logits(world->policy));
    }
}

static void m_policy_step(World *world, const void *const *args, void *result) {
    int64_t obs_values = float_count(args[0]), rows = float_count(args[1]), values = 0, resized = 0;
    if (world->policy != NULL && obs_values == rows * mp_observation_size(world->policy)) values = rows * mp_logits(world->policy);
    GDExtensionConstTypePtr resize_args[] = {&values};
    floats_resize(result, resize_args, &resized, 1);
    if (values > 0 && resized == 0 && mp_step(world->policy, float_data(args[0]), float_data(args[1]), (int)rows, floats_at(result, 0)) != MP_OK) {
        values = 0;
        floats_resize(result, resize_args, &resized, 1);
    }
}

static void m_policy_hidden(World *world, const void *const *args, void *result) {
    int64_t rows = float_count(args[0]), values = 0, resized = 0;
    if (world->policy != NULL) values = rows * mp_hidden(world->policy);
    GDExtensionConstTypePtr resize_args[] = {&values};
    floats_resize(result, resize_args, &resized, 1);
    if (values > 0 && resized == 0 && mp_memory_of(world->policy, float_data(args[0]), (int)rows, floats_at(result, 0)) != MP_OK) {
        values = 0;
        floats_resize(result, resize_args, &resized, 1);
    }
}

static void m_policy_reset_slot(World *world, const void *const *args, void *result) {
    mp_reset_slot(world->policy, (int)arg_int(args, 0));
    *(int64_t *)result = MP_OK;
}

static void m_policy_memory_hash(World *world, const void *const *args, void *result) {
    (void)args;
    *(int64_t *)result = (int64_t)mp_memory_hash(world->policy);
}

static void m_bake(World *world, const void *const *args, void *result) {
    int64_t w = arg_int(args, 0), h = arg_int(args, 1);
    int64_t rect_values = float_count(args[5]);
    if (world->nav == NULL) {
        *(int64_t *)result = MN_ERR_STATE;
    } else if (w < 4 || h < 4 || w > 4096 || h > 4096 || byte_count(args[4]) != w * h || rect_values % 4 != 0) {
        *(int64_t *)result = MN_ERR_ARGUMENT;
    } else {
        *(int64_t *)result = mn_bake(world->nav, (int)w, (int)h, (float)arg_float(args, 2), (float)arg_float(args, 3),
                                     bytes_at(args[4], 0), float_data(args[5]), (int)(rect_values / 4));
    }
}

static void m_set_targets(World *world, const void *const *args, void *result) {
    int64_t values = float_count(args[0]);
    if (world->nav == NULL) *(int64_t *)result = MN_ERR_STATE;
    else if (values % 2 != 0) *(int64_t *)result = MN_ERR_ARGUMENT;
    else *(int64_t *)result = mn_set_targets(world->nav, float_data(args[0]), (int)(values / 2));
}

static void m_load_agents(World *world, const void *const *args, void *result) {
    int64_t values = float_count(args[0]);
    if (world->nav == NULL) *(int64_t *)result = MN_ERR_STATE;
    else if (values % MN_AGENT_STRIDE != 0) *(int64_t *)result = MN_ERR_ARGUMENT;
    else *(int64_t *)result = mn_agents_load(world->nav, float_data(args[0]), (int)(values / MN_AGENT_STRIDE));
}

static void m_command_agents(World *world, const void *const *args, void *result) {
    int64_t values = float_count(args[0]);
    if (world->nav == NULL) *(int64_t *)result = MN_ERR_STATE;
    else if (values % MN_COMMAND_STRIDE != 0) *(int64_t *)result = MN_ERR_ARGUMENT;
    else *(int64_t *)result = mn_agents_command(world->nav, float_data(args[0]), (int)(values / MN_COMMAND_STRIDE));
}

static void m_bake_air(World *world, const void *const *args, void *result) {
    int64_t length = byte_count(args[0]);
    if (world->nav == NULL) *(int64_t *)result = MN_ERR_STATE;
    else *(int64_t *)result = mn_bake_air(world->nav, length > 0 ? bytes_at(args[0], 0) : NULL, length);
}

static void m_set_lazy_fields(World *world, const void *const *args, void *result) {
    *(int64_t *)result = world->nav != NULL ? mn_set_lazy_fields(world->nav, (int)arg_int(args, 0)) : MN_ERR_STATE;
}

static void m_set_layers(World *world, const void *const *args, void *result) {
    int64_t length = byte_count(args[0]);
    if (world->nav == NULL) *(int64_t *)result = MN_ERR_STATE;
    else if (length > INT32_MAX) *(int64_t *)result = MN_ERR_ARGUMENT;
    else *(int64_t *)result = mn_set_layers(world->nav, length > 0 ? bytes_at(args[0], 0) : NULL, (int)length);
}

static void m_place_agents(World *world, const void *const *args, void *result) {
    int64_t values = float_count(args[0]);
    if (world->nav == NULL) *(int64_t *)result = MN_ERR_STATE;
    else if (values % MN_PLACE_STRIDE != 0) *(int64_t *)result = MN_ERR_ARGUMENT;
    else *(int64_t *)result = mn_agents_place(world->nav, float_data(args[0]), (int)(values / MN_PLACE_STRIDE));
}

static void m_displace_agents(World *world, const void *const *args, void *result) {
    int64_t values = float_count(args[0]);
    if (world->nav == NULL) *(int64_t *)result = MN_ERR_STATE;
    else if (values % MN_DISPLACE_STRIDE != 0) *(int64_t *)result = MN_ERR_ARGUMENT;
    else *(int64_t *)result = mn_agents_displace(world->nav, float_data(args[0]), (int)(values / MN_DISPLACE_STRIDE));
}

static void m_line_clear_batch(World *world, const void *const *args, void *result) {
    int64_t values = float_count(args[0]);
    int64_t count = values % MN_SIGHT_STRIDE == 0 && world->nav != NULL ? values / MN_SIGHT_STRIDE : 0, resized = 0;
    GDExtensionConstTypePtr resize_args[] = {&count};
    bytes_resize(result, resize_args, &resized, 1);
    if (count > 0 && resized == 0) {
        mn_line_clear_batch(world->nav, float_data(args[0]), (int)count, bytes_at_mutable(result, 0));
    }
}

static void m_sight_clear_batch(World *world, const void *const *args, void *result) {
    int64_t values = float_count(args[0]);
    int64_t count = values % MN_SIGHT_STRIDE == 0 && world->nav != NULL ? values / MN_SIGHT_STRIDE : 0, resized = 0;
    GDExtensionConstTypePtr resize_args[] = {&count};
    bytes_resize(result, resize_args, &resized, 1);
    if (count > 0 && resized == 0) {
        mn_sight_clear_batch(world->nav, float_data(args[0]), (int)count, bytes_at_mutable(result, 0));
    }
}

static void m_air_clearance(World *world, const void *const *args, void *result) {
    *(double *)result = world->nav != NULL ? (double)mn_air_clearance(world->nav, (float)arg_float(args, 0), (float)arg_float(args, 1)) : -1.0;
}

static void m_sight_clear(World *world, const void *const *args, void *result) {
    *(int64_t *)result = world->nav != NULL ? mn_sight_clear(world->nav, (float)arg_float(args, 0), (float)arg_float(args, 1),
        (float)arg_float(args, 2), (float)arg_float(args, 3), (float)arg_float(args, 4)) : 0;
}

static void m_nearest_batch(World *world, const void *const *args, void *result) {
    int64_t count = float_count(args[0]), k = arg_int(args, 2);
    int64_t values = world->nav != NULL && k >= 1 && k <= MN_NEAREST_MAX ? count * k : 0, resized = 0;
    GDExtensionConstTypePtr resize_args[] = {&values};
    floats_resize(result, resize_args, &resized, 1);
    if (values > 0 && resized == 0) {
        mn_nearest_batch(world->nav, float_data(args[0]), (int)count, (float)arg_float(args, 1), (int)k, floats_at(result, 0));
    }
}

static void m_wall_rays(World *world, const void *const *args, void *result) {
    int64_t count = float_count(args[0]);
    int64_t values = world->nav != NULL ? count * MN_WALL_RAYS : 0, resized = 0;
    GDExtensionConstTypePtr resize_args[] = {&values};
    floats_resize(result, resize_args, &resized, 1);
    if (values > 0 && resized == 0) {
        mn_wall_rays(world->nav, float_data(args[0]), (int)count, (float)arg_float(args, 1), floats_at(result, 0));
    }
}

static void m_tick(World *world, const void *const *args, void *result) {
    *(int64_t *)result = mn_tick(world->nav, (float)arg_float(args, 0));
}

static void m_positions(World *world, const void *const *args, void *result) {
    (void)args;
    int64_t values = (int64_t)mn_agent_count(world->nav) * 2, resized = 0;
    GDExtensionConstTypePtr resize_args[] = {&values};
    floats_resize(result, resize_args, &resized, 1);
    if (values > 0 && resized == 0) mn_positions(world->nav, floats_at(result, 0));
}

static void m_line_clear(World *world, const void *const *args, void *result) {
    *(int64_t *)result = mn_line_clear(world->nav, (float)arg_float(args, 0), (float)arg_float(args, 1),
                                       (float)arg_float(args, 2), (float)arg_float(args, 3), (float)arg_float(args, 4));
}

static void m_clearance(World *world, const void *const *args, void *result) {
    *(double *)result = mn_clearance(world->nav, (float)arg_float(args, 0), (float)arg_float(args, 1));
}

static void m_path_cost(World *world, const void *const *args, void *result) {
    *(double *)result = mn_path_cost(world->nav, (int)arg_int(args, 0), (float)arg_float(args, 1), (float)arg_float(args, 2));
}

static void m_state_hash(World *world, const void *const *args, void *result) {
    (void)args;
    *(int64_t *)result = (int64_t)mn_state_hash(world->nav);
}

static void m_field_solves(World *world, const void *const *args, void *result) {
    (void)args;
    *(int64_t *)result = (int64_t)mn_field_solves(world->nav);
}

static const Method methods[] = {
    {"initialize", m_initialize, KIND_INT, 2, {KIND_INT, KIND_INT}, {"max_agents", "max_targets"}},
    {"bake", m_bake, KIND_INT, 6, {KIND_INT, KIND_INT, KIND_FLOAT, KIND_FLOAT, KIND_BYTES, KIND_FLOATS},
     {"floor_width", "floor_height", "origin_x", "origin_z", "floor_mask", "rects"}},
    {"set_targets", m_set_targets, KIND_INT, 1, {KIND_FLOATS}, {"xz"}},
    {"bake_air", m_bake_air, KIND_INT, 1, {KIND_BYTES}, {"air_mask"}},
    {"set_layers", m_set_layers, KIND_INT, 1, {KIND_BYTES}, {"layers"}},
    {"set_lazy_fields", m_set_lazy_fields, KIND_INT, 1, {KIND_INT}, {"enabled"}},
    {"load_agents", m_load_agents, KIND_INT, 1, {KIND_FLOATS}, {"data"}},
    {"command_agents", m_command_agents, KIND_INT, 1, {KIND_FLOATS}, {"data"}},
    {"place_agents", m_place_agents, KIND_INT, 1, {KIND_FLOATS}, {"data"}},
    {"displace_agents", m_displace_agents, KIND_INT, 1, {KIND_FLOATS}, {"data"}},
    {"line_clear_batch", m_line_clear_batch, KIND_BYTES, 1, {KIND_FLOATS}, {"queries"}},
    {"sight_clear_batch", m_sight_clear_batch, KIND_BYTES, 1, {KIND_FLOATS}, {"queries"}},
    {"air_clearance", m_air_clearance, KIND_FLOAT, 2, {KIND_FLOAT, KIND_FLOAT}, {"x", "z"}},
    {"sight_clear", m_sight_clear, KIND_INT, 5, {KIND_FLOAT, KIND_FLOAT, KIND_FLOAT, KIND_FLOAT, KIND_FLOAT},
     {"x0", "z0", "x1", "z1", "radius"}},
    {"nearest_batch", m_nearest_batch, KIND_FLOATS, 3, {KIND_FLOATS, KIND_FLOAT, KIND_INT}, {"slots", "radius", "count"}},
    {"wall_rays", m_wall_rays, KIND_FLOATS, 2, {KIND_FLOATS, KIND_FLOAT}, {"slots", "max_distance"}},
    {"obs_configure", m_obs_configure, KIND_INT, 1, {KIND_ARRAY}, {"config"}},
    {"obs_build", m_obs_build, KIND_FLOATS, 1, {KIND_ARRAY}, {"inputs"}},
    {"exec_configure", m_exec_configure, KIND_INT, 1, {KIND_ARRAY}, {"config"}},
    {"exec_run", m_exec_run, KIND_FLOATS, 1, {KIND_ARRAY}, {"inputs"}},
    {"decide_configure", m_decide_configure, KIND_INT, 1, {KIND_ARRAY}, {"config"}},
    {"decide_masks", m_decide_masks, KIND_BYTES, 1, {KIND_ARRAY}, {"inputs"}},
    {"decide_scripted", m_decide_scripted, KIND_BYTES, 1, {KIND_ARRAY}, {"inputs"}},
    {"sense_configure", m_sense_configure, KIND_INT, 1, {KIND_ARRAY}, {"config"}},
    {"sense_update", m_sense_update, KIND_BYTES, 1, {KIND_ARRAY}, {"inputs"}},
    {"sense_allies", m_sense_allies, KIND_BYTES, 1, {KIND_ARRAY}, {"inputs"}},
    {"sense_light_at", m_sense_light_at, KIND_FLOAT, 2, {KIND_FLOAT, KIND_FLOAT}, {"x", "z"}},
    {"sense_darkness_at", m_sense_darkness_at, KIND_FLOAT, 2, {KIND_FLOAT, KIND_FLOAT}, {"x", "z"}},
    {"sense_scent_at", m_sense_scent_at, KIND_FLOAT, 3, {KIND_INT, KIND_FLOAT, KIND_FLOAT}, {"player", "x", "z"}},
    {"exec_speeds", m_exec_speeds, KIND_FLOATS, 1, {KIND_ARRAY}, {"inputs"}},
    {"obs_reset_slot", m_obs_reset_slot, KIND_INT, 1, {KIND_INT}, {"slot"}},
    {"policy_load", m_policy_load, KIND_INT, 3, {KIND_BYTES, KIND_BYTES, KIND_FLOATS}, {"weights", "schema_hash", "layout"}},
    {"policy_forward", m_policy_forward, KIND_FLOATS, 2, {KIND_FLOATS, KIND_FLOATS}, {"observations", "hidden"}},
    {"policy_step", m_policy_step, KIND_FLOATS, 2, {KIND_FLOATS, KIND_FLOATS}, {"observations", "slots"}},
    {"policy_reset_slot", m_policy_reset_slot, KIND_INT, 1, {KIND_INT}, {"slot"}},
    {"policy_hidden", m_policy_hidden, KIND_FLOATS, 1, {KIND_FLOATS}, {"slots"}},
    {"policy_memory_hash", m_policy_memory_hash, KIND_INT, 0, {KIND_INT}, {NULL}},
    {"tick", m_tick, KIND_INT, 1, {KIND_FLOAT}, {"delta"}},
    {"positions", m_positions, KIND_FLOATS, 0, {KIND_INT}, {NULL}},
    {"line_clear", m_line_clear, KIND_INT, 5, {KIND_FLOAT, KIND_FLOAT, KIND_FLOAT, KIND_FLOAT, KIND_FLOAT},
     {"x0", "z0", "x1", "z1", "radius"}},
    {"clearance", m_clearance, KIND_FLOAT, 2, {KIND_FLOAT, KIND_FLOAT}, {"x", "z"}},
    {"path_cost", m_path_cost, KIND_FLOAT, 3, {KIND_INT, KIND_FLOAT, KIND_FLOAT}, {"target", "x", "z"}},
    {"state_hash", m_state_hash, KIND_INT, 0, {KIND_INT}, {NULL}},
    {"field_solves", m_field_solves, KIND_INT, 0, {KIND_INT}, {NULL}},
};

static void variant_call(void *userdata, GDExtensionClassInstancePtr instance,
                         const GDExtensionConstVariantPtr *args, GDExtensionInt count,
                         GDExtensionVariantPtr result, GDExtensionCallError *error) {
    const Method *method = userdata;
    error->error = GDEXTENSION_CALL_OK;
    if (instance == NULL) {
        error->error = GDEXTENSION_CALL_ERROR_INSTANCE_IS_NULL;
        return;
    }
    if (count != method->argument_count) {
        error->error = count < method->argument_count ? GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS
                                                      : GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        error->expected = method->argument_count;
        return;
    }
    const void *values[MAX_ARGS] = {0};
    for (int i = 0; i < method->argument_count; i++) {
        Kind kind = method->kinds[i];
        if (variant_type(args[i]) != variant_kinds[kind]) {
            error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
            error->argument = i;
            error->expected = (int32_t)variant_kinds[kind];
            return;
        }
        values[i] = internal_value[kind]((GDExtensionVariantPtr)args[i]);
    }
    destroy_variant(result);
    if (method->result == KIND_FLOATS) {
        PackedStorage output;
        floats_construct(&output, NULL);
        method->run(instance, values, &output);
        to_variant[KIND_FLOATS](result, &output);
        floats_destroy(&output);
    } else if (method->result == KIND_BYTES) {
        PackedStorage output;
        bytes_construct(&output, NULL);
        method->run(instance, values, &output);
        to_variant[KIND_BYTES](result, &output);
        bytes_destroy(&output);
    } else if (method->result == KIND_FLOAT) {
        double output = 0.0;
        method->run(instance, values, &output);
        to_variant[KIND_FLOAT](result, &output);
    } else {
        int64_t output = 0;
        method->run(instance, values, &output);
        to_variant[KIND_INT](result, &output);
    }
}

static void ptr_call(void *userdata, GDExtensionClassInstancePtr instance,
                     const GDExtensionConstTypePtr *args, GDExtensionTypePtr result) {
    const Method *method = userdata;
    method->run(instance, (const void *const *)args, result);
}

static GDExtensionObjectPtr create_world(void *unused, GDExtensionBool notify) {
    (void)unused;
    World *world = calloc(1, sizeof(*world));
    if (world == NULL) return NULL;
    GDExtensionObjectPtr object = construct_object(&object_name);
    if (object == NULL) {
        free(world);
        return NULL;
    }
    attach_instance(object, &world_name, world);
    if (notify) {
        int64_t postinitialize = 0; /* Object.NOTIFICATION_POSTINITIALIZE. */
        GDExtensionBool reversed = 0;
        GDExtensionConstTypePtr args[] = {&postinitialize, &reversed};
        call_builtin(notify_method, object, args, NULL);
    }
    return object;
}

static void free_world(void *unused, GDExtensionClassInstancePtr instance) {
    (void)unused;
    World *world = instance;
    mn_destroy(world->nav);
    mo_destroy(world->obs);
    mp_destroy(world->policy);
    me_destroy(world->exec);
    md_destroy(world->decide);
    ms_destroy(world->sense);
    free(world);
}

static void register_one(const Method *method) {
    StringNameStorage empty, name, argument_names[MAX_ARGS];
    StringStorage hint;
    make_name(&empty, "");
    make_name(&name, method->name);
    make_string(&hint, "");
    GDExtensionPropertyInfo arguments[MAX_ARGS];
    GDExtensionClassMethodArgumentMetadata metadata[MAX_ARGS];
    for (int i = 0; i < method->argument_count; i++) {
        make_name(&argument_names[i], method->arguments[i]);
        arguments[i] = (GDExtensionPropertyInfo){variant_kinds[method->kinds[i]], &argument_names[i], &empty, 0, &hint, 6};
        metadata[i] = method->kinds[i] == KIND_INT ? GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64
                    : method->kinds[i] == KIND_FLOAT ? GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE
                                                     : GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
    }
    GDExtensionPropertyInfo returned = {variant_kinds[method->result], &empty, &empty, 0, &hint, 6};
    GDExtensionClassMethodInfo info = {0};
    info.name = &name;
    info.method_userdata = (void *)method;
    info.call_func = variant_call;
    info.ptrcall_func = ptr_call;
    info.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
    info.has_return_value = 1;
    info.return_value_info = &returned;
    info.return_value_metadata = method->result == KIND_INT ? GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64
                               : method->result == KIND_FLOAT ? GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE
                                                              : GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
    info.argument_count = (uint32_t)method->argument_count;
    info.arguments_info = method->argument_count ? arguments : NULL;
    info.arguments_metadata = method->argument_count ? metadata : NULL;
    register_method(library, &world_name, &info);
    for (int i = 0; i < method->argument_count; i++) destroy_name(&argument_names[i]);
    destroy_string(&hint);
    destroy_name(&name);
    destroy_name(&empty);
}

static void initialize(void *unused, GDExtensionInitializationLevel level) {
    (void)unused;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    make_name(&world_name, "MobNavWorld");
    make_name(&object_name, "RefCounted");
    StringNameStorage base_object, notification;
    make_name(&base_object, "Object");
    make_name(&notification, "notification");
    notify_method = get_method(&base_object, &notification, 4023243586);
    destroy_name(&notification);
    destroy_name(&base_object);
    if (!notify_method) return;

    GDExtensionClassCreationInfo6 creation = {0};
    creation.is_exposed = 1;
    creation.create_instance_func = create_world;
    creation.free_instance_func = free_world;
    register_class(library, &world_name, &object_name, &creation);
    for (size_t i = 0; i < sizeof(methods) / sizeof(methods[0]); i++) register_one(&methods[i]);
}

static void deinitialize(void *unused, GDExtensionInitializationLevel level) {
    (void)unused;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    if (notify_method) unregister_class(library, &world_name);
    destroy_name(&object_name);
    destroy_name(&world_name);
}

#define LOAD(var, type, name) do { var = (type)get_proc(name); if (!var) return 0; } while (0)

__declspec(dllexport) GDExtensionBool mob_nav_init(
    GDExtensionInterfaceGetProcAddress get_proc, GDExtensionClassLibraryPtr lib,
    GDExtensionInitialization *initialization) {
    GDExtensionInterfaceGetGodotVersion2 version_fn;
    LOAD(version_fn, GDExtensionInterfaceGetGodotVersion2, "get_godot_version2");
    GDExtensionGodotVersion2 version;
    version_fn(&version);
    /* The raw C interface is pinned to the engine revision this was built against. */
    if (version.major != 4 || version.minor != 7 || version.patch != 2 ||
        version.hash == NULL || strncmp(version.hash, "ed1daf0bf", 9) != 0) return 0;

    LOAD(make_name, GDExtensionInterfaceStringNameNewWithUtf8Chars, "string_name_new_with_utf8_chars");
    LOAD(make_string, GDExtensionInterfaceStringNewWithUtf8Chars, "string_new_with_utf8_chars");
    LOAD(construct_object, GDExtensionInterfaceClassdbConstructObject3, "classdb_construct_object3");
    LOAD(attach_instance, GDExtensionInterfaceObjectSetInstance, "object_set_instance");
    LOAD(register_class, GDExtensionInterfaceClassdbRegisterExtensionClass6, "classdb_register_extension_class6");
    LOAD(unregister_class, GDExtensionInterfaceClassdbUnregisterExtensionClass, "classdb_unregister_extension_class");
    LOAD(register_method, GDExtensionInterfaceClassdbRegisterExtensionClassMethod, "classdb_register_extension_class_method");
    LOAD(get_method, GDExtensionInterfaceClassdbGetMethodBind, "classdb_get_method_bind");
    LOAD(call_builtin, GDExtensionInterfaceObjectMethodBindPtrcall, "object_method_bind_ptrcall");
    LOAD(variant_type, GDExtensionInterfaceVariantGetType, "variant_get_type");
    LOAD(destroy_variant, GDExtensionInterfaceVariantDestroy, "variant_destroy");
    LOAD(bytes_at, GDExtensionInterfacePackedByteArrayOperatorIndexConst, "packed_byte_array_operator_index_const");
    LOAD(bytes_at_mutable, GDExtensionInterfacePackedByteArrayOperatorIndex, "packed_byte_array_operator_index");
    LOAD(floats_at, GDExtensionInterfacePackedFloat32ArrayOperatorIndex, "packed_float32_array_operator_index");
    LOAD(floats_at_const, GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst, "packed_float32_array_operator_index_const");
    LOAD(ints_at, GDExtensionInterfacePackedInt32ArrayOperatorIndexConst, "packed_int32_array_operator_index_const");
    LOAD(array_at, GDExtensionInterfaceArrayOperatorIndexConst, "array_operator_index_const");

    GDExtensionInterfaceGetVariantGetInternalPtrFunc get_internal;
    GDExtensionInterfaceGetVariantFromTypeConstructor get_from_type;
    GDExtensionInterfaceVariantGetPtrDestructor get_destructor;
    GDExtensionInterfaceVariantGetPtrConstructor get_constructor;
    GDExtensionInterfaceVariantGetPtrBuiltinMethod get_builtin;
    LOAD(get_internal, GDExtensionInterfaceGetVariantGetInternalPtrFunc, "variant_get_ptr_internal_getter");
    LOAD(get_from_type, GDExtensionInterfaceGetVariantFromTypeConstructor, "get_variant_from_type_constructor");
    LOAD(get_destructor, GDExtensionInterfaceVariantGetPtrDestructor, "variant_get_ptr_destructor");
    LOAD(get_constructor, GDExtensionInterfaceVariantGetPtrConstructor, "variant_get_ptr_constructor");
    LOAD(get_builtin, GDExtensionInterfaceVariantGetPtrBuiltinMethod, "variant_get_ptr_builtin_method");

    for (int kind = 0; kind < KIND_COUNT; kind++) {
        internal_value[kind] = get_internal(variant_kinds[kind]);
        to_variant[kind] = get_from_type(variant_kinds[kind]);
        if (!internal_value[kind] || !to_variant[kind]) return 0;
    }
    internal_ints = get_internal(GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY);
    if (!internal_ints) return 0;
    floats_construct = get_constructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY, 0);
    floats_destroy = get_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY);
    bytes_construct = get_constructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY, 0);
    bytes_destroy = get_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY);
    destroy_name = get_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
    destroy_string = get_destructor(GDEXTENSION_VARIANT_TYPE_STRING);
    if (!floats_construct || !floats_destroy || !bytes_construct || !bytes_destroy || !destroy_name || !destroy_string) return 0;

    StringNameStorage size_name, resize_name;
    make_name(&size_name, "size");
    make_name(&resize_name, "resize");
    bytes_size = get_builtin(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY, &size_name, 3173160232);
    floats_size = get_builtin(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY, &size_name, 3173160232);
    floats_resize = get_builtin(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY, &resize_name, 848867239);
    bytes_resize = get_builtin(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY, &resize_name, 848867239);
    ints_size = get_builtin(GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY, &size_name, 3173160232);
    array_size = get_builtin(GDEXTENSION_VARIANT_TYPE_ARRAY, &size_name, 3173160232);
    destroy_name(&size_name);
    destroy_name(&resize_name);
    if (!bytes_size || !floats_size || !floats_resize || !bytes_resize || !ints_size || !array_size) return 0;

    library = lib;
    *initialization = (GDExtensionInitialization){
        .minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE,
        .initialize = initialize,
        .deinitialize = deinitialize,
    };
    return 1;
}
