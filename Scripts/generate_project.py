#!/usr/bin/env python3
"""Generate a dependency-free Xcode project; app includes the Foundation core directly.
No XcodeGen, CocoaPods, packages, team ID, HealthKit or paid entitlements required.
"""
from pathlib import Path
import hashlib, plistlib
ROOT = Path(__file__).resolve().parents[1]
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def q(text): return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'
objects = {}
def obj(key, body):
    ident = uid(key); objects[ident] = '{ ' + body + ' };'; return ident
sources = sorted(ROOT.glob('App/*.swift')) + sorted(ROOT.glob('Core/Sources/SleepCore/*.swift'))
refs, builds = [], []
for file in sources:
    rel = str(file.relative_to(ROOT))
    ref = obj('file:'+rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel)}; sourceTree = "<group>";')
    refs.append(ref)
    builds.append(obj('build:'+rel, f'isa = PBXBuildFile; fileRef = {ref};'))
plist = obj('plist', 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = App/Info.plist; sourceTree = "<group>";')
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = SleepLedger.app; sourceTree = BUILT_PRODUCTS_DIR;')
group = obj('group', 'isa = PBXGroup; children = (' + ','.join(refs+[plist,uid('products')]) + ',); sourceTree = "<group>";')
obj('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
phase = obj('sources', 'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(builds) + ',); runOnlyForDeploymentPostprocessing = 0;')
frameworks = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
resources = obj('resources', 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
for mode in ('Debug', 'Release'):
    common = 'SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES; '
    obj('project:'+mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ {common} }};')
    settings = common + 'PRODUCT_BUNDLE_IDENTIFIER = me.hamzabsst.SleepLedger; PRODUCT_NAME = "$(TARGET_NAME)"; INFOPLIST_FILE = App/Info.plist; GENERATE_INFOPLIST_FILE = NO; CODE_SIGN_STYLE = Automatic; TARGETED_DEVICE_FAMILY = 1; MARKETING_VERSION = 1.0; CURRENT_PROJECT_VERSION = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; SWIFT_EMIT_LOC_STRINGS = YES; ENABLE_USER_SCRIPT_SANDBOXING = YES; '
    settings += 'SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;' if mode == 'Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
    obj('target:'+mode, f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ {settings} }};')
for kind in ('project', 'target'):
    obj('configs:'+kind, 'isa = XCConfigurationList; buildConfigurations = (' + ','.join(uid(kind+':'+m) for m in ('Debug','Release')) + ',); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {uid("configs:target")}; buildPhases = ({phase},{frameworks},{resources},); buildRules = (); dependencies = (); name = SleepLedger; productName = SleepLedger; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {uid("configs:project")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {group}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
projectdir = ROOT / 'SleepLedger.xcodeproj'; projectdir.mkdir(exist_ok=True)
(projectdir/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(k+' = '+v for k,v in objects.items()) + f'\n}}; rootObject = {project}; }}\n')
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="SleepLedger.app" BlueprintName="SleepLedger" ReferencedContainer="container:SleepLedger.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="SleepLedger.app" BlueprintName="SleepLedger" ReferencedContainer="container:SleepLedger.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="SleepLedger.app" BlueprintName="SleepLedger" ReferencedContainer="container:SleepLedger.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
schemepath = projectdir/'xcshareddata/xcschemes/SleepLedger.xcscheme'; schemepath.parent.mkdir(parents=True,exist_ok=True); schemepath.write_text(scheme)
info = {
    'CFBundleDevelopmentRegion':'en', 'CFBundleDisplayName':'SleepLedger', 'CFBundleExecutable':'$(EXECUTABLE_NAME)',
    'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleInfoDictionaryVersion':'6.0',
    'CFBundleName':'$(PRODUCT_NAME)', 'CFBundlePackageType':'APPL', 'CFBundleShortVersionString':'$(MARKETING_VERSION)',
    'CFBundleVersion':'$(CURRENT_PROJECT_VERSION)', 'LSRequiresIPhoneOS': True, 'UILaunchScreen':{},
    'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'],
    'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False,'UISceneConfigurations':{}},
    'UIApplicationSupportsIndirectInputEvents':True,
    'CFBundleURLTypes':[{'CFBundleURLName':'me.hamzabsst.sleepledger','CFBundleURLSchemes':['sleepledger']}],
    'CFBundleDocumentTypes':[{'CFBundleTypeName':'SleepLedger transfer','CFBundleTypeRole':'Viewer','LSHandlerRank':'Alternate','LSItemContentTypes':['public.json','public.comma-separated-values-text']}],
    'LSSupportsOpeningDocumentsInPlace':True,
}
(ROOT/'App/Info.plist').write_bytes(plistlib.dumps(info,sort_keys=False))
print(f'Generated {len(sources)} Swift source references: {projectdir}')
