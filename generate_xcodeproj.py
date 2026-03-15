#!/usr/bin/env python3
import os, hashlib, json

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ_DIR = os.path.join(ROOT, "SleepAnalyser.xcodeproj")
os.makedirs(PROJ_DIR, exist_ok=True)

def sid(name):
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()

class PBXObjects:
    def __init__(self):
        self.file_refs = {}
        self.build_files = {}
        self.groups = {}
        self.lines = []

    def get_file_ref(self, rel_path, file_type=None):
        if rel_path in self.file_refs:
            return self.file_refs[rel_path]
        fid = sid("fr_" + rel_path)
        if file_type is None:
            if rel_path.endswith(".swift"):
                file_type = "sourcecode.swift"
            elif rel_path.endswith(".plist"):
                file_type = "text.plist.xml"
            elif rel_path.endswith(".strings"):
                file_type = "text.plist.strings"
            elif rel_path.endswith(".c"):
                file_type = "sourcecode.c.c"
            elif rel_path.endswith(".h"):
                file_type = "sourcecode.c.h"
            else:
                file_type = "text"
        self.file_refs[rel_path] = (fid, file_type)
        return (fid, file_type)

    def get_build_file(self, rel_path, phase="sources"):
        key = phase + "_" + rel_path
        if key in self.build_files:
            return self.build_files[key]
        bid = sid("bf_" + key)
        fid = self.get_file_ref(rel_path)[0]
        self.build_files[key] = (bid, fid)
        return (bid, fid)

obj = PBXObjects()

def build_group_tree(base_dir, prefix, root_name):
    tree = {}
    for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, base_dir)):
        dirnames.sort()
        rel_dir = os.path.relpath(dirpath, ROOT)
        entries = []
        for d in sorted(dirnames):
            child_rel = os.path.join(rel_dir, d)
            child_has_files = False
            for _, _, fs in os.walk(os.path.join(ROOT, child_rel)):
                if any(f.endswith(('.swift', '.plist', '.strings', '.c', '.h')) for f in fs):
                    child_has_files = True
                    break
            if child_has_files:
                entries.append(('dir', d, child_rel))
        for f in sorted(filenames):
            if f.endswith(('.swift', '.plist', '.strings', '.c', '.h')):
                entries.append(('file', f, os.path.join(rel_dir, f)))
        tree[rel_dir] = entries
    return tree

def emit_groups(tree, rel_dir, group_id):
    entries = tree.get(rel_dir, [])
    child_ids = []
    for kind, name, path in entries:
        if kind == 'dir':
            gid = sid("grp_" + path)
            child_ids.append(gid)
            emit_groups(tree, path, gid)
        else:
            fid, ftype = obj.get_file_ref(path)
            child_ids.append(fid)
    
    dir_name = os.path.basename(rel_dir)
    children_str = ",\n".join(f"\t\t\t\t{c}" for c in child_ids)
    obj.groups[rel_dir] = (group_id, dir_name, child_ids)

app_tree = build_group_tree("SleepAnalyser", "SleepAnalyser", "SleepAnalyser")
test_tree = build_group_tree("SleepAnalyserTests", "SleepAnalyserTests", "SleepAnalyserTests")

app_root_gid = sid("grp_SleepAnalyser")
test_root_gid = sid("grp_SleepAnalyserTests")
emit_groups(app_tree, "SleepAnalyser", app_root_gid)
emit_groups(test_tree, "SleepAnalyserTests", test_root_gid)

proj_id = sid("project")
main_group_id = sid("main_group_root")
products_group_id = sid("products_group")
app_target_id = sid("app_target")
test_target_id = sid("test_target")
app_product_id = sid("app_product_ref")
test_product_id = sid("test_product_ref")
info_plist_fid = sid("fr_Info.plist")

app_bcl = sid("app_build_config_list")
test_bcl = sid("test_build_config_list")
proj_bcl = sid("proj_build_config_list")
app_dbg = sid("app_debug_cfg")
app_rel = sid("app_release_cfg")
test_dbg = sid("test_debug_cfg")
test_rel = sid("test_release_cfg")
proj_dbg = sid("proj_debug_cfg")
proj_rel = sid("proj_release_cfg")
app_src_phase = sid("app_src_phase")
test_src_phase = sid("test_src_phase")
app_fw_phase = sid("app_fw_phase")
test_fw_phase = sid("test_fw_phase")
app_res_phase = sid("app_res_phase")
dep_id = sid("target_dep")
dep_proxy = sid("dep_proxy")

xcassets_fid = sid("fr_Assets.xcassets")
xcassets_bf = sid("bf_Assets.xcassets")

ml_models = ["SleepStageClassifier", "SnoreDetector", "NoiseContextClassifier"]
ml_fids = {m: sid(f"fr_{m}.mlmodelc") for m in ml_models}
ml_bfs = {m: sid(f"bf_{m}.mlmodelc") for m in ml_models}

app_swift = [p for p in obj.file_refs if p.startswith("SleepAnalyser/") and p.endswith(".swift")]
app_c = [p for p in obj.file_refs if p.startswith("SleepAnalyser/") and p.endswith(".c")]
app_plist = [p for p in obj.file_refs if p.startswith("SleepAnalyser/") and p.endswith(".plist")]
app_strings = [p for p in obj.file_refs if p.startswith("SleepAnalyser/") and p.endswith(".strings")]
test_swift = [p for p in obj.file_refs if p.startswith("SleepAnalyserTests/") and p.endswith(".swift")]

for f in app_swift:
    obj.get_build_file(f, "app_src")
for f in app_c:
    obj.get_build_file(f, "app_src")
for f in app_plist:
    obj.get_build_file(f, "app_res")
for f in app_strings:
    obj.get_build_file(f, "app_res")
for f in test_swift:
    obj.get_build_file(f, "test_src")

L = []
def w(s=""): L.append(s)

w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {};")
w("\tobjectVersion = 56;")
w("\tobjects = {")
w()

w("/* Begin PBXBuildFile section */")
for key, (bid, fid) in sorted(obj.build_files.items()):
    fname = os.path.basename(key.split("_", 1)[1])
    w(f"\t\t{bid} = {{isa = PBXBuildFile; fileRef = {fid}; }};")
w(f"\t\t{xcassets_bf} = {{isa = PBXBuildFile; fileRef = {xcassets_fid}; }};")
for m in ml_models:
    w(f"\t\t{ml_bfs[m]} = {{isa = PBXBuildFile; fileRef = {ml_fids[m]}; }};")
w("/* End PBXBuildFile section */")
w()

w("/* Begin PBXContainerItemProxy section */")
w(f"\t\t{dep_proxy} = {{")
w(f"\t\t\tisa = PBXContainerItemProxy;")
w(f"\t\t\tcontainerPortal = {proj_id};")
w(f"\t\t\tproxyType = 1;")
w(f"\t\t\tremoteGlobalIDString = {app_target_id};")
w(f"\t\t\tremoteInfo = SleepAnalyser;")
w(f"\t\t}};")
w("/* End PBXContainerItemProxy section */")
w()

w("/* Begin PBXFileReference section */")
w(f"\t\t{app_product_id} = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SleepAnalyser.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
w(f"\t\t{test_product_id} = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = SleepAnalyserTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
w(f"\t\t{info_plist_fid} = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
for rel_path, (fid, ftype) in sorted(obj.file_refs.items()):
    fname = os.path.basename(rel_path)
    w(f"\t\t{fid} = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = \"{fname}\"; sourceTree = \"<group>\"; }};")
w(f"\t\t{xcassets_fid} = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
for m in ml_models:
    w(f"\t\t{ml_fids[m]} = {{isa = PBXFileReference; lastKnownFileType = folder; path = \"SleepAnalyser/Resources/ML/{m}.mlmodelc\"; sourceTree = SOURCE_ROOT; }};")
w("/* End PBXFileReference section */")
w()

w("/* Begin PBXFrameworksBuildPhase section */")
w(f"\t\t{app_fw_phase} = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
w(f"\t\t{test_fw_phase} = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
w("/* End PBXFrameworksBuildPhase section */")
w()

w("/* Begin PBXGroup section */")

w(f"\t\t{main_group_id} = {{")
w(f"\t\t\tisa = PBXGroup;")
w(f"\t\t\tchildren = ({app_root_gid}, {test_root_gid}, {products_group_id}, {info_plist_fid});")
w(f"\t\t\tsourceTree = \"<group>\";")
w(f"\t\t}};")

w(f"\t\t{products_group_id} = {{")
w(f"\t\t\tisa = PBXGroup;")
w(f"\t\t\tchildren = ({app_product_id}, {test_product_id});")
w(f"\t\t\tname = Products;")
w(f"\t\t\tsourceTree = \"<group>\";")
w(f"\t\t}};")

for rel_dir in sorted(obj.groups.keys()):
    gid, name, child_ids = obj.groups[rel_dir]
    entries = app_tree.get(rel_dir) or test_tree.get(rel_dir) or []
    
    ordered_ids = []
    for kind, ename, path in entries:
        if kind == 'dir':
            ordered_ids.append(sid("grp_" + path))
        else:
            ordered_ids.append(obj.file_refs[path][0])
    
    if rel_dir == os.path.join("SleepAnalyser", "Resources"):
        ordered_ids.append(xcassets_fid)

    if rel_dir == os.path.join("SleepAnalyser", "Resources", "ML"):
        for m in ml_models:
            ordered_ids.append(ml_fids[m])
    
    children = ", ".join(ordered_ids) if len(ordered_ids) <= 3 else ",\n".join(f"\t\t\t\t{c}" for c in ordered_ids)
    
    w(f"\t\t{gid} = {{")
    w(f"\t\t\tisa = PBXGroup;")
    if len(ordered_ids) <= 3:
        w(f"\t\t\tchildren = ({children});")
    else:
        w(f"\t\t\tchildren = (")
        for c in ordered_ids:
            w(f"\t\t\t\t{c},")
        w(f"\t\t\t);")
    w(f"\t\t\tpath = \"{name}\";")
    w(f"\t\t\tsourceTree = \"<group>\";")
    w(f"\t\t}};")

w("/* End PBXGroup section */")
w()

w("/* Begin PBXNativeTarget section */")
w(f"\t\t{app_target_id} = {{")
w(f"\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {app_bcl};")
w(f"\t\t\tbuildPhases = ({app_src_phase}, {app_fw_phase}, {app_res_phase});")
w(f"\t\t\tbuildRules = ();")
w(f"\t\t\tdependencies = ();")
w(f"\t\t\tname = SleepAnalyser;")
w(f"\t\t\tproductName = SleepAnalyser;")
w(f"\t\t\tproductReference = {app_product_id};")
w(f"\t\t\tproductType = \"com.apple.product-type.application\";")
w(f"\t\t}};")

w(f"\t\t{test_target_id} = {{")
w(f"\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {test_bcl};")
w(f"\t\t\tbuildPhases = ({test_src_phase}, {test_fw_phase});")
w(f"\t\t\tbuildRules = ();")
w(f"\t\t\tdependencies = ({dep_id});")
w(f"\t\t\tname = SleepAnalyserTests;")
w(f"\t\t\tproductName = SleepAnalyserTests;")
w(f"\t\t\tproductReference = {test_product_id};")
w(f"\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
w(f"\t\t}};")
w("/* End PBXNativeTarget section */")
w()

w("/* Begin PBXProject section */")
w(f"\t\t{proj_id} = {{")
w(f"\t\t\tisa = PBXProject;")
w(f"\t\t\tbuildConfigurationList = {proj_bcl};")
w(f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
w(f"\t\t\tdevelopmentRegion = en;")
w(f"\t\t\thasScannedForEncodings = 0;")
w(f"\t\t\tknownRegions = (en, \"zh-Hans\", \"zh-Hant\", Base);")
w(f"\t\t\tmainGroup = {main_group_id};")
w(f"\t\t\tproductRefGroup = {products_group_id};")
w(f"\t\t\tprojectDirPath = \"\";")
w(f"\t\t\tprojectRoot = \"\";")
w(f"\t\t\ttargets = ({app_target_id}, {test_target_id});")
w(f"\t\t}};")
w("/* End PBXProject section */")
w()

w("/* Begin PBXResourcesBuildPhase section */")
w(f"\t\t{app_res_phase} = {{")
w(f"\t\t\tisa = PBXResourcesBuildPhase;")
w(f"\t\t\tbuildActionMask = 2147483647;")
res_bids = [obj.build_files["app_res_" + f][0] for f in app_plist]
res_bids += [obj.build_files["app_res_" + f][0] for f in app_strings]
res_bids.append(xcassets_bf)
for m in ml_models:
    res_bids.append(ml_bfs[m])
w(f"\t\t\tfiles = ({', '.join(res_bids)});")
w(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t\t}};")
w("/* End PBXResourcesBuildPhase section */")
w()

w("/* Begin PBXSourcesBuildPhase section */")
w(f"\t\t{app_src_phase} = {{")
w(f"\t\t\tisa = PBXSourcesBuildPhase;")
w(f"\t\t\tbuildActionMask = 2147483647;")
w(f"\t\t\tfiles = (")
for f in sorted(app_swift + app_c):
    bid = obj.build_files["app_src_" + f][0]
    w(f"\t\t\t\t{bid},")
w(f"\t\t\t);")
w(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t\t}};")

w(f"\t\t{test_src_phase} = {{")
w(f"\t\t\tisa = PBXSourcesBuildPhase;")
w(f"\t\t\tbuildActionMask = 2147483647;")
w(f"\t\t\tfiles = (")
for f in sorted(test_swift):
    bid = obj.build_files["test_src_" + f][0]
    w(f"\t\t\t\t{bid},")
w(f"\t\t\t);")
w(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w(f"\t\t}};")
w("/* End PBXSourcesBuildPhase section */")
w()

w("/* Begin PBXTargetDependency section */")
w(f"\t\t{dep_id} = {{isa = PBXTargetDependency; target = {app_target_id}; targetProxy = {dep_proxy}; }};")
w("/* End PBXTargetDependency section */")
w()

common = """				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SWIFT_VERSION = 5.0;
				SDKROOT = macosx;"""

w("/* Begin XCBuildConfiguration section */")
for cfg_id, name, extra in [
    (proj_dbg, "Debug", f'{common}\n\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG";\n\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;\n\t\t\t\tONLY_ACTIVE_ARCH = YES;\n\t\t\t\tENABLE_TESTABILITY = YES;\n\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";'),
    (proj_rel, "Release", f'{common}\n\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;\n\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'),
]:
    w(f"\t\t{cfg_id} = {{")
    w(f"\t\t\tisa = XCBuildConfiguration;")
    w(f"\t\t\tbuildSettings = {{")
    w(extra)
    w(f"\t\t\t}};")
    w(f"\t\t\tname = {name};")
    w(f"\t\t}};")

app_extra = """				PRODUCT_BUNDLE_IDENTIFIER = com.sleepanalyser.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				INFOPLIST_FILE = Info.plist;
				COMBINE_HIDPI_IMAGES = YES;
				CODE_SIGN_STYLE = Automatic;
				GENERATE_INFOPLIST_FILE = YES;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				INFOPLIST_KEY_NSMicrophoneUsageDescription = "SleepAnalyser needs microphone access to analyze your breathing patterns during sleep.";
				INFOPLIST_KEY_NSMainStoryboardFile = "";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.healthcare-fitness";
				SWIFT_OBJC_BRIDGING_HEADER = "SleepAnalyser/SleepAnalyser-Bridging-Header.h";"""

for cfg_id, name in [(app_dbg, "Debug"), (app_rel, "Release")]:
    w(f"\t\t{cfg_id} = {{")
    w(f"\t\t\tisa = XCBuildConfiguration;")
    w(f"\t\t\tbuildSettings = {{")
    w(app_extra)
    w(f"\t\t\t}};")
    w(f"\t\t\tname = {name};")
    w(f"\t\t}};")

test_extra = """				PRODUCT_BUNDLE_IDENTIFIER = com.sleepanalyser.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				BUNDLE_LOADER = "$(TEST_HOST)";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/SleepAnalyser.app/Contents/MacOS/SleepAnalyser";
				GENERATE_INFOPLIST_FILE = YES;"""

for cfg_id, name in [(test_dbg, "Debug"), (test_rel, "Release")]:
    w(f"\t\t{cfg_id} = {{")
    w(f"\t\t\tisa = XCBuildConfiguration;")
    w(f"\t\t\tbuildSettings = {{")
    w(test_extra)
    w(f"\t\t\t}};")
    w(f"\t\t\tname = {name};")
    w(f"\t\t}};")

w("/* End XCBuildConfiguration section */")
w()

w("/* Begin XCConfigurationList section */")
for cl_id, cfgs, name in [
    (proj_bcl, f"{proj_dbg}, {proj_rel}", "project"),
    (app_bcl, f"{app_dbg}, {app_rel}", "app"),
    (test_bcl, f"{test_dbg}, {test_rel}", "test"),
]:
    w(f"\t\t{cl_id} = {{")
    w(f"\t\t\tisa = XCConfigurationList;")
    w(f"\t\t\tbuildConfigurations = ({cfgs});")
    w(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    w(f"\t\t\tdefaultConfigurationName = Release;")
    w(f"\t\t}};")
w("/* End XCConfigurationList section */")
w()

w(f"\t}};")
w(f"\trootObject = {proj_id};")
w("}")

with open(os.path.join(PROJ_DIR, "project.pbxproj"), "w") as f:
    f.write("\n".join(L) + "\n")

print(f"Generated xcodeproj with nested groups")
print(f"  App sources: {len(app_swift)} swift + {len(app_plist)} plist")
print(f"  Test sources: {len(test_swift)} swift")
print(f"  Groups: {len(obj.groups)}")
