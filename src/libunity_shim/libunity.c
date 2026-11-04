/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: LGPL-2.1-or-later

    Native lightweight Unity LauncherEntry shim for Chromium/Brave on Wayland/Plasma 6.
    Allows Chromium's DownloadStatusUpdater to transmit download progress and badges
    directly over the session DBus without requiring the full legacy Ubuntu Unity stack.
*/

#include <gio/gio.h>
#include <string.h>
#include <stdio.h>

#define UNITY_API __attribute__((visibility("default")))

struct _UnityInspector {
    int dummy;
};
typedef struct _UnityInspector UnityInspector;

struct _UnityLauncherEntry {
    char *desktop_id;
    double progress;
    gboolean progress_visible;
    gint64 count;
    gboolean count_visible;
};
typedef struct _UnityLauncherEntry UnityLauncherEntry;

static UnityInspector s_inspector = {0};
static GDBusConnection *s_bus_connection = NULL;

UNITY_API UnityInspector* unity_inspector_get_default(void) {
    return &s_inspector;
}

UNITY_API gboolean unity_inspector_get_unity_running(UnityInspector* self) {
    (void)self;
    return TRUE;
}

static void send_update_signal(UnityLauncherEntry *entry) {
    if (!entry || !entry->desktop_id) {
        return;
    }

    if (!s_bus_connection) {
        GError *err = NULL;
        s_bus_connection = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &err);
        if (!s_bus_connection) {
            if (err) {
                g_error_free(err);
            }
            return;
        }
    }

    GVariantBuilder builder;
    g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));
    g_variant_builder_add(&builder, "{sv}", "progress", g_variant_new_double(entry->progress));
    g_variant_builder_add(&builder, "{sv}", "progress-visible", g_variant_new_boolean(entry->progress_visible));
    g_variant_builder_add(&builder, "{sv}", "count", g_variant_new_int64(entry->count));
    g_variant_builder_add(&builder, "{sv}", "count-visible", g_variant_new_boolean(entry->count_visible));

    char app_uri[512];
    if (strncmp(entry->desktop_id, "application://", 14) == 0) {
        snprintf(app_uri, sizeof(app_uri), "%s", entry->desktop_id);
    } else {
        snprintf(app_uri, sizeof(app_uri), "application://%s", entry->desktop_id);
    }

    GVariant *body = g_variant_new("(sa{sv})", app_uri, &builder);

    g_dbus_connection_emit_signal(
        s_bus_connection,
        NULL,
        "/com/canonical/unity/launcherentry",
        "com.canonical.Unity.LauncherEntry",
        "Update",
        body,
        NULL
    );
}

UNITY_API UnityLauncherEntry* unity_launcher_entry_get_for_desktop_id(const gchar* desktop_id) {
    UnityLauncherEntry *entry = g_new0(UnityLauncherEntry, 1);
    entry->desktop_id = g_strdup(desktop_id);
    return entry;
}

UNITY_API void unity_launcher_entry_set_count(UnityLauncherEntry* self, gint64 value) {
    if (!self) return;
    self->count = value;
    send_update_signal(self);
}

UNITY_API void unity_launcher_entry_set_count_visible(UnityLauncherEntry* self, gboolean value) {
    if (!self) return;
    self->count_visible = value;
    send_update_signal(self);
}

UNITY_API void unity_launcher_entry_set_progress(UnityLauncherEntry* self, gdouble value) {
    if (!self) return;
    self->progress = value;
    send_update_signal(self);
}

UNITY_API void unity_launcher_entry_set_progress_visible(UnityLauncherEntry* self, gboolean value) {
    if (!self) return;
    self->progress_visible = value;
    send_update_signal(self);
}
