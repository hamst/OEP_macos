cmake_minimum_required(VERSION 3.9)

project(offscreen_effect_player_macos LANGUAGES C CXX OBJC OBJCXX Swift)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(BNB_RESOURCES_FOLDER ${CMAKE_CURRENT_LIST_DIR}/resources)
set(BNB_THIRD_FOLDER ${CMAKE_CURRENT_LIST_DIR}/third)

# Set to OFF to disable ffmpeg dependency (SDK should be built with disabled video_player also)
set(BNB_VIDEO_PLAYER ON)

add_definitions(
    -DBNB_RESOURCES_FOLDER="${BNB_RESOURCES_FOLDER}"
    -DBNB_VIDEO_PLAYER=$<BOOL:${BNB_VIDEO_PLAYER}>
)

include(${CMAKE_CURRENT_LIST_DIR}/cmake/copy_libs.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/utils.cmake)

add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/bnb_sdk)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/third)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/libraries)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/offscreen_effect_player)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/offscreen_render_target)

option(DEPLOY_BUILD "Build for deployment" OFF)

set(APP_NAME "example_mac") 

set(CMAKE_XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${PROJECT_SOURCE_DIR}/BNBObjCHeaders.h")
set(CMAKE_XCODE_ATTRIBUTE_SWIFT_OBJC_INTERFACE_HEADER_NAME "MySwiftInterfaceHeader.h")

set(APP_HEADER_FILES
    ./BNBObjCHeaders.h
)

set(APP_SOURCE_FILES
    AppDelegate.swift
    ViewController.swift
)

set(RESOURCES
    ${BNB_RESOURCES_FOLDER}/Main.storyboard
    ${BNB_RESOURCES_FOLDER}/bnb_viewer.icns
)

add_executable(${APP_NAME}
    ${APP_HEADER_FILES}
    ${APP_SOURCE_FILES}
    ${RESOURCES}
)

target_link_libraries(${APP_NAME}
    offscreen_ep
)

set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15")
set(CMAKE_XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES")


set(EXAMPLE_BUNDLE_NAME "Banuba Offscreen Rendering Example") # This name can contain up to 15 characters according to Apple's documentation
set(EXAMPLE_COPYRIGHT "© 2021 Banuba. All rights reserved.")
set(EXAMPLE_INFO "Banuba Offscreen Rendering Example.")

set_target_properties(${APP_NAME} PROPERTIES
    OUTPUT_NAME ${EXAMPLE_BUNDLE_NAME}
    RESOURCE "${RESOURCES}"
    MACOSX_BUNDLE TRUE

    # The same as stadrard MacOSXBundleInfo.plist.in from CMake but with camera permissions added
    MACOSX_BUNDLE_INFO_PLIST ${BNB_RESOURCES_FOLDER}/Info.plist

    MACOSX_BUNDLE_BUNDLE_NAME           ${EXAMPLE_BUNDLE_NAME}                # Sets CFBundleName
    MACOSX_BUNDLE_COPYRIGHT             ${EXAMPLE_COPYRIGHT}                  # Sets NSHumanReadableCopyright
    MACOSX_BUNDLE_GUI_IDENTIFIER        "com.banuba.sdk.offsceen.mac.sample"  # Sets CFBundleIdentifier
    MACOSX_BUNDLE_ICON_FILE             bnb_viewer.icns                       # Sets CFBundleIconFile
    MACOSX_BUNDLE_INFO_STRING           ${EXAMPLE_INFO}                       # Sets CFBundleGetInfoString

    # Explicitly skip code signing (CMake tries to turn it on for application bundles)
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
)
target_link_libraries(${APP_NAME}
    "-framework Accelerate"    
    "-framework Cocoa"
    "-framework Foundation"
    "-framework OpenGL"
)

copy_sdk(${APP_NAME})
copy_third(${APP_NAME})
