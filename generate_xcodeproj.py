#!/usr/bin/env python3
"""Generate SleepAnalyser.xcodeproj with app + test targets."""
import os, uuid, hashlib

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ_DIR = os.path.join(ROOT, "SleepAnalyser.xcodeproj")
os.makedirs(PROJ_DIR, exist_ok=True)

def stable_id(name):
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()

# Collect source files
app_sources = []
test_sources = []
for dirpath, _, filenames in os.walk(os.path.join(ROOT, "SleepAnalyser")):
    for f in sorted(filenames):
        if f.endswith(".swift"):
            rel = os.path.relpath(os.path.join(dirpath, f), ROOT)
            app_sources.append(rel)
        elif f.endswith(".plist"):
            rel = os.path.relpath(os.path.join(dirpath, f), ROOT)
            app_sources.append(rel)

for dirpath, _, filenames in os.walk(os.path.join(ROOT, "SleepAnalyserTests")):
    for f in sorted(filenames):
        if f.endswith(".swift"):
            rel = os.path.relpath(os.path.join(dirpath, f), ROOT)
            test_sources.append(rel)

# IDs
proj_id = stable_id("project")
main_group_id = stable_id("main_group")
app_group_id = stable_id("app_group")
test_group_id = stable_id("test_group")
products_group_id = stable_id("products_group")
app_target_id = stable_id("app_target")
test_target_id = stable_id("test_target")
app_product_id = stable_id("app_product")
test_product_id = stable_id("test_product")
app_build_config_list_id = stable_id("app_build_config_list")
test_build_config_list_id = stable_id("test_build_config_list")
proj_build_config_list_id = stable_id("proj_build_config_list")
app_debug_config_id = stable_id("app_debug_config")
app_release_config_id = stable_id("app_release_config")
test_debug_config_id = stable_id("test_debug_config")
test_release_config_id = stable_id("test_release_config")
proj_debug_config_id = stable_id("proj_debug_config")
proj_release_config_id = stable_id("proj_release_config")
app_sources_phase_id = stable_id("app_sources_phase")
test_sources_phase_id = stable_id("test_sources_phase")
app_frameworks_phase_id = stable_id("app_frameworks_phase")
test_frameworks_phase_id = stable_id("test_frameworks_phase")
app_resources_phase_id = stable_id("app_resources_phase")
dep_id = stable_id("dependency")
dep_proxy_id = stable_id("dep_proxy")
info_plist_id = stable_id("info_plist")

file_refs = {}
build_files_app = {}
build_files_test = {}
resource_build_files = {}

for f in app_sources:
    fid = stable_id("fr_" + f)
    file_refs[f] = fid
    if f.endswith(".swift"):
        build_files_app[f] = stable_id("bf_" + f)
    elif f.endswith(".plist"):
        resource_build_files[f] = stable_id("rb_" + f)

for f in test_sources:
    fid = stable_id("fr_" + f)
    file_refs[f] = fid
    build_files_test[f] = stable_id("bf_" + f)

# Build pbxproj
lines = []
def w(s=""): lines.append(s)

w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {};")
w("\tobjectVersion = 56;")
w("\tobjects = {")
w()

# PBXBuildFile
w("/* Begin PBXBuildFile section */")
for f, bid in sorted(build_files_app.items()):
    w(f'\t\t{bid} /* {os.path.basename(f)} */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]}; }};')
for f, bid in sorted(resource_build_files.items()):
    w(f'\t\t{bid} /* {os.path.basename(f)} */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]}; }};')
for f, bid in sorted(build_files_test.items()):
    w(f'\t\t{bid} /* {os.path.basename(f)} */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]}; }};')
w("/* End PBXBuildFile section */")
w()

# PBXContainerItemProxy
w("/* Begin PBXContainerItemProxy section */")
w(f"\t\t{dep_proxy_id} = {{")
w("\t\t\tisa = PBXContainerItemProxy;")
w(f"\t\t\tcontainerPortal = {proj_id};")
w("\t\t\tproxyType = 1;")
w(f"\t\t\tremoteGlobalIDString = {app_target_id};")
w('\t\t\tremoteInfo = SleepAnalyser;')
w("\t\t};")
w("/* End PBXContainerItemProxy section */")
w()

# PBXFileReference
w("/* Begin PBXFileReference section */")
w(f'\t\t{app_product_id} = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SleepAnalyser.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
w(f'\t\t{test_product_id} = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = SleepAnalyserTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')
w(f'\t\t{info_plist_id} = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
for f, fid in sorted(file_refs.items()):
    ftype = "sourcecode.swift" if f.endswith(".swift") else "text.plist.xml"
    w(f'\t\t{fid} /* {os.path.basename(f)} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{f}"; sourceTree = "<group>"; }};')
w("/* End PBXFileReference section */")
w()

# PBXFrameworksBuildPhase
w("/* Begin PBXFrameworksBuildPhase section */")
w(f"\t\t{app_frameworks_phase_id} = {{ isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
w(f"\t\t{test_frameworks_phase_id} = {{ isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
w("/* End PBXFrameworksBuildPhase section */")
w()

# PBXGroup
w("/* Begin PBXGroup section */")
w(f"\t\t{main_group_id} = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w(f"\t\t\t\t{app_group_id},")
w(f"\t\t\t\t{test_group_id},")
w(f"\t\t\t\t{products_group_id},")
w(f"\t\t\t\t{info_plist_id},")
w("\t\t\t);")
w('\t\t\tsourceTree = "<group>";')
w("\t\t};")

# App sources group
w(f"\t\t{app_group_id} = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
for f in sorted(app_sources):
    w(f"\t\t\t\t{file_refs[f]},")
w("\t\t\t);")
w('\t\t\tpath = "";')
w('\t\t\tname = SleepAnalyser;')
w('\t\t\tsourceTree = "<group>";')
w("\t\t};")

# Test sources group
w(f"\t\t{test_group_id} = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
for f in sorted(test_sources):
    w(f"\t\t\t\t{file_refs[f]},")
w("\t\t\t);")
w('\t\t\tpath = "";')
w('\t\t\tname = SleepAnalyserTests;')
w('\t\t\tsourceTree = "<group>";')
w("\t\t};")

# Products group
w(f"\t\t{products_group_id} = {{")
w("\t\t\tisa = PBXGroup;")
w(f"\t\t\tchildren = ({app_product_id}, {test_product_id});")
w('\t\t\tname = Products;')
w('\t\t\tsourceTree = "<group>";')
w("\t\t};")
w("/* End PBXGroup section */")
w()

# PBXNativeTarget
w("/* Begin PBXNativeTarget section */")
w(f"\t\t{app_target_id} = {{")
w("\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {app_build_config_list_id};")
w("\t\t\tbuildPhases = (")
w(f"\t\t\t\t{app_sources_phase_id},")
w(f"\t\t\t\t{app_frameworks_phase_id},")
w(f"\t\t\t\t{app_resources_phase_id},")
w("\t\t\t);")
w("\t\t\tbuildRules = ();")
w("\t\t\tdependencies = ();")
w("\t\t\tname = SleepAnalyser;")
w(f"\t\t\tproductName = SleepAnalyser;")
w(f"\t\t\tproductReference = {app_product_id};")
w('\t\t\tproductType = "com.apple.product-type.application";')
w("\t\t};")

w(f"\t\t{test_target_id} = {{")
w("\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {test_build_config_list_id};")
w("\t\t\tbuildPhases = (")
w(f"\t\t\t\t{test_sources_phase_id},")
w(f"\t\t\t\t{test_frameworks_phase_id},")
w("\t\t\t);")
w("\t\t\tbuildRules = ();")
w(f"\t\t\tdependencies = ({dep_id});")
w("\t\t\tname = SleepAnalyserTests;")
w(f"\t\t\tproductName = SleepAnalyserTests;")
w(f"\t\t\tproductReference = {test_product_id};")
w('\t\t\tproductType = "com.apple.product-type.bundle.unit-test";')
w("\t\t};")
w("/* End PBXNativeTarget section */")
w()

# PBXProject
w("/* Begin PBXProject section */")
w(f"\t\t{proj_id} = {{")
w("\t\t\tisa = PBXProject;")
w(f"\t\t\tbuildConfigurationList = {proj_build_config_list_id};")
w('\t\t\tcompatibilityVersion = "Xcode 14.0";')
w("\t\t\tdevelopmentRegion = en;")
w("\t\t\thasScannedForEncodings = 0;")
w("\t\t\tknownRegions = (en, Base);")
w(f"\t\t\tmainGroup = {main_group_id};")
w(f"\t\t\tproductRefGroup = {products_group_id};")
w('\t\t\tprojectDirPath = "";')
w('\t\t\tprojectRoot = "";')
w(f"\t\t\ttargets = ({app_target_id}, {test_target_id});")
w("\t\t};")
w("/* End PBXProject section */")
w()

# PBXResourcesBuildPhase
w("/* Begin PBXResourcesBuildPhase section */")
w(f"\t\t{app_resources_phase_id} = {{")
w("\t\t\tisa = PBXResourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for f, bid in sorted(resource_build_files.items()):
    w(f"\t\t\t\t{bid},")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXResourcesBuildPhase section */")
w()

# PBXSourcesBuildPhase
w("/* Begin PBXSourcesBuildPhase section */")
w(f"\t\t{app_sources_phase_id} = {{")
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for f, bid in sorted(build_files_app.items()):
    w(f"\t\t\t\t{bid},")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")

w(f"\t\t{test_sources_phase_id} = {{")
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for f, bid in sorted(build_files_test.items()):
    w(f"\t\t\t\t{bid},")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXSourcesBuildPhase section */")
w()

# PBXTargetDependency
w("/* Begin PBXTargetDependency section */")
w(f"\t\t{dep_id} = {{")
w("\t\t\tisa = PBXTargetDependency;")
w(f"\t\t\ttarget = {app_target_id};")
w(f"\t\t\ttargetProxy = {dep_proxy_id};")
w("\t\t};")
w("/* End PBXTargetDependency section */")
w()

# Build configs
common_settings = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SWIFT_VERSION = 5.0;
				SDKROOT = macosx;"""

w("/* Begin XCBuildConfiguration section */")
# Project debug
w(f"\t\t{proj_debug_config_id} = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
w(common_settings)
w('\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG";')
w('\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;')
w("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
w("\t\t\t\tENABLE_TESTABILITY = YES;")
w("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
w("\t\t\t};")
w('\t\t\tname = Debug;')
w("\t\t};")
# Project release
w(f"\t\t{proj_release_config_id} = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
w(common_settings)
w('\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;')
w('\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
w("\t\t\t};")
w('\t\t\tname = Release;')
w("\t\t};")
# App debug
w(f"\t\t{app_debug_config_id} = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
w('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.sleepanalyser.app;')
w('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
w(f'\t\t\t\tINFOPLIST_FILE = Info.plist;')
w('\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;')
w('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
w('\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;')
w('\t\t\t\tGENERATE_INFOPLIST_FILE = YES;')
w('\t\t\t\tINFOPLIST_KEY_NSMicrophoneUsageDescription = "SleepAnalyser needs microphone access to analyze your breathing patterns during sleep.";')
w('\t\t\t\tINFOPLIST_KEY_NSMainStoryboardFile = "";')
w('\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.healthcare-fitness";')
w("\t\t\t};")
w('\t\t\tname = Debug;')
w("\t\t};")
# App release
w(f"\t\t{app_release_config_id} = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
w('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.sleepanalyser.app;')
w('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
w(f'\t\t\t\tINFOPLIST_FILE = Info.plist;')
w('\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;')
w('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
w('\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;')
w('\t\t\t\tGENERATE_INFOPLIST_FILE = YES;')
w('\t\t\t\tINFOPLIST_KEY_NSMicrophoneUsageDescription = "SleepAnalyser needs microphone access to analyze your breathing patterns during sleep.";')
w('\t\t\t\tINFOPLIST_KEY_NSMainStoryboardFile = "";')
w('\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.healthcare-fitness";')
w("\t\t\t};")
w('\t\t\tname = Release;')
w("\t\t};")
# Test debug
w(f"\t\t{test_debug_config_id} = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
w('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.sleepanalyser.tests;')
w('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
w('\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";')
w('\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/SleepAnalyser.app/Contents/MacOS/SleepAnalyser";')
w('\t\t\t\tGENERATE_INFOPLIST_FILE = YES;')
w("\t\t\t};")
w('\t\t\tname = Debug;')
w("\t\t};")
# Test release
w(f"\t\t{test_release_config_id} = {{")
w("\t\t\tisa = XCBuildConfiguration;")
w("\t\t\tbuildSettings = {")
w('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.sleepanalyser.tests;')
w('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
w('\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";')
w('\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/SleepAnalyser.app/Contents/MacOS/SleepAnalyser";')
w('\t\t\t\tGENERATE_INFOPLIST_FILE = YES;')
w("\t\t\t};")
w('\t\t\tname = Release;')
w("\t\t};")
w("/* End XCBuildConfiguration section */")
w()

# XCConfigurationList
w("/* Begin XCConfigurationList section */")
w(f"\t\t{proj_build_config_list_id} = {{")
w("\t\t\tisa = XCConfigurationList;")
w(f"\t\t\tbuildConfigurations = ({proj_debug_config_id}, {proj_release_config_id});")
w('\t\t\tdefaultConfigurationIsVisible = 0;')
w('\t\t\tdefaultConfigurationName = Release;')
w("\t\t};")
w(f"\t\t{app_build_config_list_id} = {{")
w("\t\t\tisa = XCConfigurationList;")
w(f"\t\t\tbuildConfigurations = ({app_debug_config_id}, {app_release_config_id});")
w('\t\t\tdefaultConfigurationIsVisible = 0;')
w('\t\t\tdefaultConfigurationName = Release;')
w("\t\t};")
w(f"\t\t{test_build_config_list_id} = {{")
w("\t\t\tisa = XCConfigurationList;")
w(f"\t\t\tbuildConfigurations = ({test_debug_config_id}, {test_release_config_id});")
w('\t\t\tdefaultConfigurationIsVisible = 0;')
w('\t\t\tdefaultConfigurationName = Release;')
w("\t\t};")
w("/* End XCConfigurationList section */")
w()

w("\t};")
w(f"\trootObject = {proj_id};")
w("}")

pbxproj_path = os.path.join(PROJ_DIR, "project.pbxproj")
with open(pbxproj_path, "w") as f:
    f.write("\n".join(lines) + "\n")

print(f"Generated {pbxproj_path}")
print(f"  App sources: {len(app_sources)} files")
print(f"  Test sources: {len(test_sources)} files")
