cmake_minimum_required(VERSION 3.20)
project(macos-dock LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GIO REQUIRED gio-2.0)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Widgets Quick Qml DBus Test)
find_package(KF6 6.0 REQUIRED COMPONENTS CoreAddons WindowSystem I18n Config Package DBusAddons KIO Service)
find_package(Plasma 6.0 REQUIRED)
find_package(PlasmaQuick 6.0 REQUIRED)
find_package(CachyOSUITesting REQUIRED)
find_package(LayerShellQt REQUIRED)
find_package(LibNotificationManager REQUIRED)

add_executable(macos-dock
    src/main.cpp
    src/dockcorona.cpp
    src/dockcorona.h
    src/dockview.cpp
    src/dockview.h
    src/dockbackend.cpp
    src/dockbackend.h
    src/dockindicatormanager.cpp
    src/dockindicatormanager.h
)

target_link_libraries(macos-dock PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Quick
    Qt6::Qml
    Qt6::DBus
    KF6::CoreAddons
    KF6::WindowSystem
    KF6::I18n
    KF6::ConfigCore
    KF6::Package
    KF6::DBusAddons
    KF6::KIOCore
    KF6::KIOGui
    KF6::Service
    Plasma::Plasma
    Plasma::PlasmaQuick
    LayerShellQt::Interface
    PW::LibNotificationManager
)

# Native Unity LauncherEntry shim library for Chromium / Brave
add_library(unity SHARED
    src/libunity_shim/libunity.c
)
set_target_properties(unity PROPERTIES
    OUTPUT_NAME "unity"
    SOVERSION "9"
    VERSION "9.0.0"
)
target_include_directories(unity PRIVATE ${GIO_INCLUDE_DIRS})
target_link_libraries(unity PRIVATE ${GIO_LIBRARIES})

install(TARGETS macos-dock unity ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})

# Unit tests
include(CTest)
if(BUILD_TESTING)
    add_executable(test_dockindicatormanager
        tests/test_dockindicatormanager.cpp
        src/dockindicatormanager.cpp
        src/dockindicatormanager.h
    )

    target_include_directories(test_dockindicatormanager PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )

    target_link_libraries(test_dockindicatormanager PRIVATE
        Qt6::Core
        Qt6::DBus
        Qt6::Test
        KF6::ConfigCore
        KF6::Service
        PW::LibNotificationManager
    )

    add_test(NAME test_dockindicatormanager COMMAND test_dockindicatormanager)

    add_executable(test_layout_audit
        tests/test_layout_audit.cpp
        src/dockcorona.cpp
        src/dockcorona.h
        src/dockview.cpp
        src/dockview.h
        src/dockbackend.cpp
        src/dockbackend.h
        src/dockindicatormanager.cpp
        src/dockindicatormanager.h
    )

    target_include_directories(test_layout_audit PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )

    target_link_libraries(test_layout_audit PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Quick
        Qt6::Qml
        Qt6::DBus
        Qt6::Test
        KF6::CoreAddons
        KF6::WindowSystem
        KF6::ConfigCore
        KF6::Package
        KF6::DBusAddons
        KF6::Service
        KF6::KIOCore
        KF6::KIOGui
        Plasma::Plasma
        Plasma::PlasmaQuick
        LayerShellQt::Interface
        PW::LibNotificationManager
        CachyOSUITesting::CachyOSUITesting
    )

    add_test(NAME test_layout_audit COMMAND test_layout_audit)
    set_tests_properties(test_layout_audit PROPERTIES
        ENVIRONMENT "CACHYOS_UI_IMPORT_PATH=$ENV{HOME}/.local/lib/qt6/qml"
    )
endif()
