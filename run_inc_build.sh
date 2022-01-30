#!/bin/bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Check if we have enough arguments.
if [ "$#" -ne 4 ] ; then
    echo "run_inc_build.sh <repo_url> <new_commit> <old_commit> <output_path> - requires 4 arguments"
    exit
fi

# -------------------------------------------------------
# Example:
# repo_url: https://github.com/xi-liu-ds/githubactions-1.git
# new commit with bug fix: ffe3e3c2ca2dfc9c17b980631d05129eac554f05
# old commit with bug: 862057c6c7fd10e07db6033731cec5239c13faba
# -------------------------------------------------------

infer_args_list=("--enable-issue-type NULL_DEREFERENCE" "--enable-issue-type DOTNET_RESOURCE_LEAK" "--enable-issue-type THREAD_SAFETY_VIOLATION")

# Clear issue types if specific issue is mentioned in arguments
for v in "$@" 
do
    if [[ $v == --enable* ]]; then
        infer_args_list=()
    fi
done

# Parse arguments
if [ "$#" -gt 1 ]; then
    i=2
    while [ $i -le $# ]
    do
        if [ ${!i} == "--enable-null-dereference" ]; then
            infer_args_list+=("--enable-issue-type NULL_DEREFERENCE")
        elif [ ${!i} == "--enable-dotnet-resource-leak" ]; then
            infer_args_list+=("--enable-issue-type DOTNET_RESOURCE_LEAK")
        elif [ ${!i} == "--enable-thread-safety-violation" ]; then
            infer_args_list+=("--enable-issue-type THREAD_SAFETY_VIOLATION")
        elif [ ${!i} == "--sarif" ]; then
            infer_args_list+=("--sarif")
        fi
        ((i++))
    done
fi

# Dynamically create the issue types
infer_args=""
for infer_arg in "${infer_args_list[@]}"
do
    infer_args="$infer_args $infer_arg"
done

# Prepare incremental build result folder
rm -r results
mkdir -p results


# Getting changed file list
rm -r new_commit
mkdir -p new_commit
git clone $1 new_commit
cd new_commit
echo "Processing {$1}"
echo "Getting changed file list between branch {$2} and {$3}..."
git diff --name-only $2..$3 > index.txt

## first run: new commit
git checkout $2
cd ConsoleApp1
dotnet build
cd ..

# Preparation
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"
if [ -d infer-out ]; then rm -Rf infer-out; fi
if [ -d infer-staging ]; then rm -Rf infer-staging; fi
coreLibraryPath=../Cilsil/bin/System.Private.CoreLib.dll
echo -e "Copying binaries to a staging folder...\n"
mkdir infer-staging
cp -r $coreLibraryPath ConsoleApp1/ConsoleApp1/bin infer-staging

# Run InferSharp analysis.
echo -e "Code translation started..."
dotnet ../Cilsil/bin/Debug/net5.0/Cilsil.dll translate infer-staging --outcfg infer-staging/cfg.json --outtenv infer-staging/tenv.json --cfgtxt infer-staging/cfg.txt
echo -e "Code translation completed. Analyzing...\n"
infer capture
mkdir infer-out/captured 
infer $(infer help --list-issue-types 2> /dev/null | grep ':true:' | cut -d ':' -f 1 | sed -e 's/^/--disable-issue-type /') $infer_args analyzejson --cfg-json infer-staging/cfg.json --tenv-json infer-staging/tenv.json
# store the infer report
cp infer-out/report.json ../results/report-current.json


## second run: old commit
cd ..
rm -r old_commit
mkdir -p old_commit
git clone $1 old_commit
cd old_commit
git checkout $3
cd ConsoleApp1
dotnet build
cd ..

# Preparation
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"
if [ -d infer-out ]; then rm -Rf infer-out; fi
if [ -d infer-staging ]; then rm -Rf infer-staging; fi
echo -e "Copying binaries to a staging folder...\n"
mkdir infer-staging
cp -r $coreLibraryPath ConsoleApp1/ConsoleApp1/bin infer-staging

# run capture in reactive mode so that previously-captured source files are kept if they are up-to-date
echo -e "Code translation started..."
dotnet ../Cilsil/bin/Debug/net5.0/Cilsil.dll translate infer-staging --outcfg infer-staging/cfg.json --outtenv infer-staging/tenv.json --cfgtxt infer-staging/cfg.txt
echo -e "Code translation completed. Analyzing...\n"
infer capture --reactive
mkdir infer-out/captured 
infer $(infer help --list-issue-types 2> /dev/null | grep ':true:' | cut -d ':' -f 1 | sed -e 's/^/--disable-issue-type /') $infer_args analyzejson --cfg-json infer-staging/cfg.json --tenv-json infer-staging/tenv.json --changed-files-index ../new_commit/index.txt
# store the infer report
cp infer-out/report.json ../results/report-previous.json

# compare reports
cd ../results/
infer reportdiff --debug --report-current report-current.json --report-previous report-previous.json
# move report to save to output_path
echo "Outputting diffs to {$4}..."
rm -r $4
mkdir -p $4
cp -r infer-out/differential/ $4
