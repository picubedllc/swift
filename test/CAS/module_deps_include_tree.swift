// REQUIRES: objc_interop

// RUN: %empty-directory(%t)
// RUN: mkdir -p %t/clang-module-cache
// RUN: mkdir -p %t/cas

// RUN: %target-swift-frontend -scan-dependencies -module-load-mode prefer-interface -module-cache-path %t/clang-module-cache %s -o %t/deps.json -I %S/../ScanDependencies/Inputs/CHeaders -I %S/../ScanDependencies/Inputs/Swift -emit-dependencies -emit-dependencies-path %t/deps.d -import-objc-header %S/../ScanDependencies/Inputs/CHeaders/Bridging.h -swift-version 4 -enable-cross-import-overlays -cache-compile-job -cas-path %t/cas -auto-bridging-header-chaining

// Check the contents of the JSON output
// RUN: %FileCheck %s -check-prefix CHECK -check-prefix CHECK-NO-SEARCH-PATHS < %t/deps.json

// Check the make-style dependencies file
// RUN: %FileCheck %s -check-prefix CHECK-MAKE-DEPS < %t/deps.d

// RUN: %target-swift-frontend -scan-dependencies -module-load-mode prefer-interface -test-dependency-scan-cache-serialization -module-cache-path %t/clang-module-cache %s -o %t/deps.json -I %S/../ScanDependencies/Inputs/CHeaders -I %S/../ScanDependencies/Inputs/Swift -import-objc-header %S/../ScanDependencies/Inputs/CHeaders/Bridging.h -swift-version 4 -enable-cross-import-overlays -cache-compile-job -cas-path %t/cas -auto-bridging-header-chaining

// Ensure that scanning with `-clang-target` makes sure that Swift modules' respective PCM-dependency-build-argument sets do not contain target triples.
// RUN: %target-swift-frontend -scan-dependencies -module-load-mode prefer-interface -module-cache-path %t/clang-module-cache %s -o %t/deps_clang_target.json -I %S/../ScanDependencies/Inputs/CHeaders -I %S/../ScanDependencies/Inputs/Swift -import-objc-header %S/../ScanDependencies/Inputs/CHeaders/Bridging.h -swift-version 4 -enable-cross-import-overlays -clang-target %target-cpu-apple-macosx10.14 -cache-compile-job -cas-path %t/cas -auto-bridging-header-chaining

/// check cas-fs content
// RUN: %{python} %S/Inputs/SwiftDepsExtractor.py %t/deps.json E casFSRootID > %t/E_fs.casid
// RUN: %cache-tool -cas-path %t/cas -cache-tool-action print-include-tree-list @%t/E_fs.casid | %FileCheck %s -check-prefix FS_ROOT_E

// RUN: %{python} %S/Inputs/SwiftDepsExtractor.py %t/deps.json clang:F clangIncludeTree > %t/F_tree.casid
// RUN: clang-cas-test --cas %t/cas --print-include-tree @%t/F_tree.casid | %FileCheck %s -check-prefix INCLUDE_TREE_F

// RUN: %{python} %S/Inputs/SwiftDepsExtractor.py %t/deps.json clang:F commandLine > %t/F.cmd
// RUN: %FileCheck %s -check-prefix F_CMD -input-file=%t/F.cmd
// F_CMD: "-Xcc"
// F_CMD-NOT: "-o"

// RUN: %{python} %S/Inputs/SwiftDepsExtractor.py %t/deps.json deps commandLine > %t/deps.cmd
// RUN: %FileCheck %s -check-prefix MAIN_CMD -input-file=%t/deps.cmd

// FS_ROOT_E-DAG: E.swiftinterface
// FS_ROOT_E-DAG: SDKSettings.json

// INCLUDE_TREE_F: <module-includes>
// INCLUDE_TREE_F: <built-in>
// INCLUDE_TREE_F: Files:
// INCLUDE_TREE_F-NEXT: CHeaders/F.h

// MAIN_CMD: -direct-clang-cc1-module-build
// MAIN_CMD: -clang-include-tree-filelist

import C
import E
import G
import SubE

// CHECK: "mainModuleName": "deps"

/// --------Main module
// CHECK-LABEL: "modulePath": "deps.swiftmodule",
// CHECK-NEXT: sourceFiles
// CHECK-NEXT: module_deps_include_tree.swift
// CHECK-NEXT: ],
// CHECK-NEXT: "directDependencies": [
// CHECK-DAG:     "clang": "C"
// CHECK-DAG:     "swift": "E"
// CHECK-DAG:     "swift": "G"
// CHECK-DAG:     "swift": "SubE"
// CHECK-DAG:     "swift": "Swift"
// CHECK-DAG:     "swift": "SwiftOnoneSupport"
// CHECK-DAG:     "swift": "_Concurrency"
// CHECK-DAG:     "swift": "_cross_import_E"
// CHECK: ],

// CHECK-NOT: "error: cannot open Swift placeholder dependency module map from"
// CHECK: "bridgingHeader":
// CHECK-NEXT: "path":
// CHECK-SAME: Bridging.h

// CHECK-NEXT: "sourceFiles":
// CHECK-NEXT: ChainedBridgingHeader.h
// CHECK-NEXT: Bridging.h
// CHECK-NEXT: BridgingOther.h

// CHECK: "moduleDependencies": [
// CHECK-NEXT: "F"
// CHECK-NEXT: ]

// CHECK: "swiftOverlayDependencies": [
// CHECK-DAG:     "swift": "A"
// CHECK-DAG:     "swift": "F"

/// --------Clang module C
// CHECK-LABEL: "modulePath": "{{.*}}{{/|\\}}C-{{.*}}.pcm",

// CHECK: "sourceFiles": [
// CHECK-DAG: module.modulemap
// CHECK-DAG: C.h

// CHECK: directDependencies
// CHECK-NEXT: {
// CHECK-NEXT: "clang": "B"

// CHECK: "moduleMapPath"
// CHECK-SAME: module.modulemap

// CHECK: "contextHash"
// CHECK-SAME: "{{.*}}"

// CHECK: "commandLine": [
// CHECK:   "-fmodule-format=obj"
// CHECK:   "-dwarf-ext-refs"

/// --------Clang module B
// CHECK-LABEL: "modulePath": "{{.*}}{{/|\\}}B-{{.*}}.pcm",
// CHECK: "contextHash": "[[B_CONTEXT:.*]]",
// CHECK: "commandLine": [
// CHECK:      "-o"
// CHECK-NEXT: B-{{.*}}[[B_CONTEXT]].pcm
// CHECK:      "-fmodule-format=obj"
// CHECK:      "-dwarf-ext-refs"

// Check make-style dependencies
// CHECK-MAKE-DEPS: module_deps_include_tree.swift
// CHECK-MAKE-DEPS-SAME: A.swiftinterface
// CHECK-MAKE-DEPS-SAME: G.swiftinterface
// CHECK-MAKE-DEPS-SAME: B.h
// CHECK-MAKE-DEPS-SAME: Bridging.h
// CHECK-MAKE-DEPS-SAME: BridgingOther.h
// CHECK-MAKE-DEPS-SAME: module.modulemap

/// --------Swift module F
// CHECK:      "modulePath": "{{.*}}{{/|\\}}F-{{.*}}.swiftmodule",
// CHECK-NEXT: "sourceFiles": [
// CHECK-NEXT: ],
// CHECK-NEXT: "directDependencies": [
// CHECK-NEXT:   {
// CHECK-DAG:     "clang": "F"
// CHECK-DAG:     "swift": "Swift"
// CHECK-DAG:     "swift": "SwiftOnoneSupport"
// CHECK-NEXT:   }
// CHECK-NEXT: ],
// CHECK: "details":
// CHECK: "moduleCacheKey":

/// --------Swift module A
// CHECK-LABEL: "modulePath": "{{.*}}{{/|\\}}A-{{.*}}.swiftmodule",

// CHECK: directDependencies
// CHECK-NEXT: {
// CHECK-DAG:   "clang": "A"
// CHECK-DAG:   "swift": "Swift"
// CHECK-NEXT: }
// CHECK: "details":
// CHECK: "moduleCacheKey":

/// --------Swift module G
// CHECK-LABEL: "modulePath": "{{.*}}{{/|\\}}G-{{.*}}.swiftmodule"
// CHECK: "directDependencies"
// CHECK-NEXT: {
// CHECK-DAG:   "clang": "G"
// CHECK-DAG:   "swift": "Swift"
// CHECK-DAG:   "swift": "SwiftOnoneSupport"
// CHECK: ],
// CHECK-NEXT: "linkLibraries": [
// CHECK: "details": {

// CHECK: "commandLine": [
// CHECK: "-compile-module-from-interface"
// CHECK: "-target"
// CHECK: "-cache-compile-job"
// CHECK: "-cas-path"
// CHECK: "-module-name"
// CHECK: "G"
// CHECK: "-swift-version"
// CHECK: "5"
// CHECK: ],
// CHECK: "contextHash": "{{.*}}",

/// --------Swift module E
// CHECK: "swift": "E"
// CHECK-LABEL: modulePath": "{{.*}}{{/|\\}}E-{{.*}}.swiftmodule"
// CHECK: "directDependencies"
// CHECK-NEXT: {
// CHECK-NEXT: "swift": "Swift"

// CHECK: "moduleInterfacePath"
// CHECK-SAME: E.swiftinterface

/// --------Swift module Swift
// CHECK-LABEL: "modulePath": "{{.*}}{{/|\\}}Swift-{{.*}}.swiftmodule",

// CHECK: directDependencies
// CHECK-NEXT: {
// CHECK-NEXT: "clang": "SwiftShims"

/// --------Clang module SwiftShims
// CHECK-LABEL: "modulePath": "{{.*}}{{/|\\}}SwiftShims-{{.*}}.pcm",
// CHECK: "contextHash": "[[SHIMS_CONTEXT:.*]]",
// CHECK: "-o"
// CHECK-NEXT: SwiftShims-{{.*}}[[SHIMS_CONTEXT]].pcm
// CHECK-NO-SEARCH-PATHS-NOT: "-prebuilt-module-cache-path"
