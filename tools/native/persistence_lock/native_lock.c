#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "gdextension_interface.h"

typedef struct {
    HANDLE handle;
    DWORD last_error;
    wchar_t (*paths)[MAX_PATH];
    int64_t path_count;
} Lock;

typedef struct { void *opaque; } StringNameStorage;
typedef struct { void *opaque; } StringStorage;
typedef int64_t (*Operation)(Lock *);

static GDExtensionClassLibraryPtr library;
static StringNameStorage lock_name;
static StringNameStorage object_name;
static GDExtensionInterfaceStringNameNewWithUtf8Chars make_name;
static GDExtensionInterfaceStringNewWithUtf8Chars make_string;
static GDExtensionInterfaceStringToWideChars to_wide;
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
static GDExtensionVariantGetInternalPtrFunc get_string;
static GDExtensionVariantGetInternalPtrFunc get_paths;
static GDExtensionInterfacePackedStringArrayOperatorIndexConst get_path_at;
static GDExtensionPtrBuiltInMethod path_count;
static GDExtensionVariantFromTypeConstructorFunc return_int;
static GDExtensionPtrDestructor destroy_name;
static GDExtensionPtrDestructor destroy_string;

static DWORD check_parent_volume(wchar_t *path) {
    wchar_t *slash = wcsrchr(path, L'/');
    wchar_t *backslash = wcsrchr(path, L'\\');
    if (backslash && (!slash || backslash > slash)) slash = backslash;
    if (slash == NULL || slash <= path + 2) return ERROR_INVALID_NAME;
    wchar_t saved = *slash;
    *slash = 0;

    wchar_t volume[MAX_PATH];
    wchar_t filesystem[16];
    DWORD error = ERROR_SUCCESS;
    if (!GetVolumePathNameW(path, volume, MAX_PATH)) {
        error = GetLastError();
    } else if (GetDriveTypeW(volume) != DRIVE_FIXED) {
        error = ERROR_NOT_SUPPORTED;
    } else if (!GetVolumeInformationW(volume, NULL, 0, NULL, NULL, NULL,
                                      filesystem, sizeof(filesystem) / sizeof(filesystem[0]))) {
        error = GetLastError();
    } else if (wcscmp(filesystem, L"NTFS") != 0) {
        error = ERROR_NOT_SUPPORTED;
    }
    *slash = saved;
    return error;
}

static DWORD check_regular_file(HANDLE handle) {
    BY_HANDLE_FILE_INFORMATION info;
    if (!GetFileInformationByHandle(handle, &info)) return GetLastError();
    if ((info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) ||
        info.nNumberOfLinks != 1) return ERROR_INVALID_NAME;
    return ERROR_SUCCESS;
}

static DWORD check_participant(GDExtensionConstStringPtr path) {
    wchar_t name[MAX_PATH] = {0};
    GDExtensionInt length = to_wide(path, NULL, 0);
    if (length <= 0 || length >= MAX_PATH) return ERROR_INVALID_NAME;
    to_wide(path, name, length);
    HANDLE handle = CreateFileW(name, FILE_READ_ATTRIBUTES,
                               FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                               NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (handle == INVALID_HANDLE_VALUE) {
        DWORD error = GetLastError();
        return error == ERROR_FILE_NOT_FOUND ? ERROR_SUCCESS : error;
    }
    DWORD error = check_regular_file(handle);
    if (!CloseHandle(handle) && error == ERROR_SUCCESS) error = GetLastError();
    return error;
}

static int64_t acquire(Lock *lock, GDExtensionConstStringPtr path, GDExtensionConstTypePtr participants) {
    if (lock->handle != INVALID_HANDLE_VALUE) {
        lock->last_error = ERROR_ALREADY_EXISTS;
        return lock->last_error;
    }
    GDExtensionInt length = to_wide(path, NULL, 0);
    if (length <= 0 || length >= MAX_PATH) {
        lock->last_error = ERROR_INVALID_NAME;
        return lock->last_error;
    }
    wchar_t *name = calloc((size_t)length + 1, sizeof(*name));
    if (name == NULL) {
        lock->last_error = ERROR_OUTOFMEMORY;
        return lock->last_error;
    }
    to_wide(path, name, length);
    HANDLE handle = INVALID_HANDLE_VALUE;
    DWORD error = ERROR_INVALID_NAME;
    // The caller supplies an absolute local path. Windows resolves filesystem aliases.
    BOOL drive_absolute = length >= 3 &&
        ((name[0] >= L'A' && name[0] <= L'Z') || (name[0] >= L'a' && name[0] <= L'z')) &&
        name[1] == L':' && (name[2] == L'/' || name[2] == L'\\');
    if (drive_absolute && wcslen(name) == (size_t)length && wcschr(name + 2, L':') == NULL) {
        error = check_parent_volume(name);
        if (error == ERROR_SUCCESS) {
            handle = CreateFileW(name, GENERIC_READ | GENERIC_WRITE, 0, NULL,
                                 OPEN_ALWAYS, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
            error = handle == INVALID_HANDLE_VALUE ? GetLastError() : ERROR_SUCCESS;
        }
    }
    if (handle != INVALID_HANDLE_VALUE) {
        error = check_regular_file(handle);
        int64_t count = 0;
        path_count((GDExtensionTypePtr)participants, NULL, &count, 0);
        if (count < 0 || count > 256) error = ERROR_INVALID_PARAMETER;
        if (count > 0 && error == ERROR_SUCCESS) {
            lock->paths = calloc((size_t)count, sizeof(*lock->paths));
            if (!lock->paths) error = ERROR_OUTOFMEMORY;
        }
        for (int64_t i = 0; i < count && error == ERROR_SUCCESS; i++) {
            GDExtensionConstStringPtr path = get_path_at(participants, i);
            error = check_participant(path);
            if (error == ERROR_SUCCESS) to_wide(path, lock->paths[i], MAX_PATH - 1);
        }
        if (error == ERROR_SUCCESS) lock->path_count = count;
        else {
            free(lock->paths);
            lock->paths = NULL;
            CloseHandle(handle);
            handle = INVALID_HANDLE_VALUE;
        }
    }
    free(name);
    lock->handle = handle;
    lock->last_error = error;
    return error;
}

static int64_t release_lock(Lock *lock) {
    if (lock->handle == INVALID_HANDLE_VALUE) {
        lock->last_error = ERROR_NOT_LOCKED;
        return lock->last_error;
    }
    if (!CloseHandle(lock->handle)) {
        lock->last_error = GetLastError();
        return lock->last_error;
    }
    lock->handle = INVALID_HANDLE_VALUE;
    free(lock->paths);
    lock->paths = NULL;
    lock->path_count = 0;
    lock->last_error = ERROR_SUCCESS;
    return ERROR_SUCCESS;
}

static int64_t is_held(Lock *lock) {
    return lock->handle != INVALID_HANDLE_VALUE;
}

static int64_t last_error(Lock *lock) {
    return lock->last_error;
}

static BOOL allowed_path(const Lock *lock, const wchar_t *path) {
    for (int64_t i = 0; i < lock->path_count; i++) {
        if (wcscmp(lock->paths[i], path) == 0) return TRUE;
    }
    return FALSE;
}

static int64_t replace_authorized(Lock *lock, GDExtensionConstStringPtr source,
                                  GDExtensionConstTypePtr arguments) {
    if (lock->handle == INVALID_HANDLE_VALUE) return ERROR_NOT_LOCKED;
    int64_t count = 0;
    path_count((GDExtensionTypePtr)arguments, NULL, &count, 0);
    if (count != 1) return ERROR_INVALID_PARAMETER;
    GDExtensionConstStringPtr destination = get_path_at(arguments, 0);
    wchar_t from[MAX_PATH] = {0}, to[MAX_PATH] = {0};
    GDExtensionInt a = to_wide(source, NULL, 0), b = to_wide(destination, NULL, 0);
    if (a <= 0 || b <= 0 || a >= MAX_PATH || b >= MAX_PATH) return ERROR_INVALID_NAME;
    to_wide(source, from, a);
    to_wide(destination, to, b);
    wchar_t *parent_a = wcsrchr(from, L'/'), *parent_b = wcsrchr(to, L'/');
    if (!parent_a || !parent_b || wcslen(from) != (size_t)a || wcslen(to) != (size_t)b ||
        wcscmp(from, to) == 0 || parent_a - from != parent_b - to ||
        wcsncmp(from, to, (size_t)(parent_a - from)) != 0 ||
        !allowed_path(lock, from) || !allowed_path(lock, to)) return ERROR_INVALID_NAME;
    DWORD error = check_parent_volume(from);
    if (error == ERROR_SUCCESS) error = check_participant(source);
    if (error == ERROR_SUCCESS) error = check_participant(destination);
    if (error != ERROR_SUCCESS) return error;
    if (!MoveFileExW(from, to, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) return GetLastError();
    return ERROR_SUCCESS;
}

static int64_t path_operation(const char *method, Lock *lock, GDExtensionConstStringPtr path,
                              GDExtensionConstTypePtr arguments) {
    if (strcmp(method, "acquire") == 0) return acquire(lock, path, arguments);
    return replace_authorized(lock, path, arguments);
}

typedef struct {
    const char *name;
    Operation operation;
    unsigned argument_count;
} Method;

static const Method methods[] = {
    {"acquire", NULL, 2},
    {"replace_authorized", NULL, 2},
    {"release", release_lock, 0},
    {"is_held", is_held, 0},
    {"last_error", last_error, 0},
};

static void variant_call(void *userdata, GDExtensionClassInstancePtr instance,
                         const GDExtensionConstVariantPtr *args, GDExtensionInt count,
                         GDExtensionVariantPtr result, GDExtensionCallError *error) {
    const Method *method = userdata;
    error->error = GDEXTENSION_CALL_OK;
    if (instance == NULL) {
        error->error = GDEXTENSION_CALL_ERROR_INSTANCE_IS_NULL;
    } else if (count != method->argument_count) {
        error->error = count < method->argument_count ? GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS
                                                 : GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        error->expected = (int32_t)method->argument_count;
    } else if (count && variant_type(args[0]) != GDEXTENSION_VARIANT_TYPE_STRING) {
        error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        error->argument = 0;
        error->expected = GDEXTENSION_VARIANT_TYPE_STRING;
    } else if (count && variant_type(args[1]) != GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY) {
        error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        error->argument = 1;
        error->expected = GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY;
    } else {
        int64_t value = count ? path_operation(method->name, instance, get_string((GDExtensionVariantPtr)args[0]),
                                         get_paths((GDExtensionVariantPtr)args[1]))
                              : method->operation(instance);
        destroy_variant(result);
        return_int(result, &value);
    }
}

static void ptr_call(void *userdata, GDExtensionClassInstancePtr instance,
                     const GDExtensionConstTypePtr *args, GDExtensionTypePtr result) {
    const Method *method = userdata;
    *(int64_t *)result = method->argument_count ? path_operation(method->name, instance, args[0], args[1])
                                               : method->operation(instance);
}

static GDExtensionObjectPtr create_lock(void *unused, GDExtensionBool notify) {
    (void)unused;
    Lock *lock = malloc(sizeof(*lock));
    if (lock == NULL) return NULL;
    *lock = (Lock){ .handle = INVALID_HANDLE_VALUE };
    GDExtensionObjectPtr object = construct_object(&object_name);
    if (object == NULL) {
        free(lock);
        return NULL;
    }
    attach_instance(object, &lock_name, lock);
    if (notify) {
        int64_t postinitialize = 0; // Object.NOTIFICATION_POSTINITIALIZE.
        GDExtensionBool reversed = 0;
        GDExtensionConstTypePtr args[] = { &postinitialize, &reversed };
        call_builtin(notify_method, object, args, NULL);
    }
    return object;
}

static void free_lock(void *unused, GDExtensionClassInstancePtr instance) {
    (void)unused;
    Lock *lock = instance;
    if (lock->handle != INVALID_HANDLE_VALUE) CloseHandle(lock->handle);
    free(lock->paths);
    free(lock);
}

static void initialize(void *unused, GDExtensionInitializationLevel level) {
    (void)unused;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    make_name(&lock_name, "B0NativeLock");
    make_name(&object_name, "Object");
    StringNameStorage notification;
    make_name(&notification, "notification");
    notify_method = get_method(&object_name, &notification, 4023243586);
    destroy_name(&notification);
    if (!notify_method) return;

    GDExtensionClassCreationInfo6 creation = {0};
    creation.is_exposed = 1;
    creation.create_instance_func = create_lock;
    creation.free_instance_func = free_lock;
    register_class(library, &lock_name, &object_name, &creation);

    StringNameStorage empty, path_name, participants_name;
    StringStorage hint;
    make_name(&empty, "");
    make_name(&path_name, "path");
    make_name(&participants_name, "participants");
    make_string(&hint, "");
    GDExtensionPropertyInfo integer = {GDEXTENSION_VARIANT_TYPE_INT, &empty, &empty, 0, &hint, 6};
    GDExtensionPropertyInfo parameters[] = {
        {GDEXTENSION_VARIANT_TYPE_STRING, &path_name, &empty, 0, &hint, 6},
        {GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY, &participants_name, &empty, 0, &hint, 6},
    };
    GDExtensionClassMethodArgumentMetadata metadata[] = {
        GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE, GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
    };
    for (size_t i = 0; i < sizeof(methods) / sizeof(methods[0]); i++) {
        StringNameStorage name;
        make_name(&name, methods[i].name);
        GDExtensionClassMethodInfo method = {0};
        method.name = &name;
        method.method_userdata = (void *)&methods[i];
        method.call_func = variant_call;
        method.ptrcall_func = ptr_call;
        method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
        method.has_return_value = 1;
        method.return_value_info = &integer;
        method.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64;
        method.argument_count = methods[i].argument_count;
        method.arguments_info = method.argument_count ? parameters : NULL;
        method.arguments_metadata = method.argument_count ? metadata : NULL;
        register_method(library, &lock_name, &method);
        destroy_name(&name);
    }
    destroy_string(&hint);
    destroy_name(&participants_name);
    destroy_name(&path_name);
    destroy_name(&empty);
}

static void deinitialize(void *unused, GDExtensionInitializationLevel level) {
    (void)unused;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    if (notify_method) unregister_class(library, &lock_name);
    destroy_name(&object_name);
    destroy_name(&lock_name);
}

#define LOAD(var, type, name) do { var = (type)get_proc(name); if (!var) return 0; } while (0)

__declspec(dllexport) GDExtensionBool b0_native_lock_init(
    GDExtensionInterfaceGetProcAddress get_proc, GDExtensionClassLibraryPtr lib,
    GDExtensionInitialization *initialization) {
    GDExtensionInterfaceGetGodotVersion2 version_fn;
    LOAD(version_fn, GDExtensionInterfaceGetGodotVersion2, "get_godot_version2");
    GDExtensionGodotVersion2 version;
    version_fn(&version);
    // Deliberately pin the prototype's raw C ABI to the tested Godot revision.
    if (version.major != 4 || version.minor != 7 || version.patch != 2 ||
        version.hash == NULL || strncmp(version.hash, "ed1daf0bf", 9) != 0) return 0;

    LOAD(make_name, GDExtensionInterfaceStringNameNewWithUtf8Chars, "string_name_new_with_utf8_chars");
    LOAD(make_string, GDExtensionInterfaceStringNewWithUtf8Chars, "string_new_with_utf8_chars");
    LOAD(to_wide, GDExtensionInterfaceStringToWideChars, "string_to_wide_chars");
    LOAD(construct_object, GDExtensionInterfaceClassdbConstructObject3, "classdb_construct_object3");
    LOAD(attach_instance, GDExtensionInterfaceObjectSetInstance, "object_set_instance");
    LOAD(register_class, GDExtensionInterfaceClassdbRegisterExtensionClass6, "classdb_register_extension_class6");
    LOAD(unregister_class, GDExtensionInterfaceClassdbUnregisterExtensionClass, "classdb_unregister_extension_class");
    LOAD(register_method, GDExtensionInterfaceClassdbRegisterExtensionClassMethod, "classdb_register_extension_class_method");
    LOAD(get_method, GDExtensionInterfaceClassdbGetMethodBind, "classdb_get_method_bind");
    LOAD(call_builtin, GDExtensionInterfaceObjectMethodBindPtrcall, "object_method_bind_ptrcall");
    LOAD(variant_type, GDExtensionInterfaceVariantGetType, "variant_get_type");
    LOAD(destroy_variant, GDExtensionInterfaceVariantDestroy, "variant_destroy");
    LOAD(get_path_at, GDExtensionInterfacePackedStringArrayOperatorIndexConst, "packed_string_array_operator_index_const");

    GDExtensionInterfaceGetVariantGetInternalPtrFunc get_internal;
    GDExtensionInterfaceGetVariantFromTypeConstructor get_constructor;
    GDExtensionInterfaceVariantGetPtrDestructor get_destructor;
    GDExtensionInterfaceVariantGetPtrBuiltinMethod get_builtin;
    LOAD(get_internal, GDExtensionInterfaceGetVariantGetInternalPtrFunc, "variant_get_ptr_internal_getter");
    LOAD(get_constructor, GDExtensionInterfaceGetVariantFromTypeConstructor, "get_variant_from_type_constructor");
    LOAD(get_destructor, GDExtensionInterfaceVariantGetPtrDestructor, "variant_get_ptr_destructor");
    LOAD(get_builtin, GDExtensionInterfaceVariantGetPtrBuiltinMethod, "variant_get_ptr_builtin_method");
    get_string = get_internal(GDEXTENSION_VARIANT_TYPE_STRING);
    get_paths = get_internal(GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY);
    return_int = get_constructor(GDEXTENSION_VARIANT_TYPE_INT);
    destroy_name = get_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
    destroy_string = get_destructor(GDEXTENSION_VARIANT_TYPE_STRING);
    if (!get_string || !get_paths || !return_int || !destroy_name || !destroy_string) return 0;
    StringNameStorage size_name;
    make_name(&size_name, "size");
    path_count = get_builtin(GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY, &size_name, 3173160232);
    destroy_name(&size_name);
    if (!path_count) return 0;

    library = lib;
    *initialization = (GDExtensionInitialization){
        .minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE,
        .initialize = initialize,
        .deinitialize = deinitialize,
    };
    return 1;
}
