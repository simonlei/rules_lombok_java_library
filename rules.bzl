load("@rules_java//java:defs.bzl", "java_library")

DEFAULT_LOMBOK_JAR = "@lombok_jar//jar"
DEFAULT_TOOLCHAIN = "@bazel_tools//tools/jdk:current_java_runtime"

def lombok_java_library(name, srcs, deps = [], package_path = "", lombok_jar = DEFAULT_LOMBOK_JAR, toolchain = DEFAULT_TOOLCHAIN, debug = False):
    line = "$(JAVA) -Dfile.encoding=UTF8 -jar $(location " + lombok_jar + ") delombok "
    files = dict()

    for src in srcs:
        names = src.rsplit("/", 1)
        if len(names)>1:
            path, file_name = src.rsplit("/", 1)
            path =  path + "/"
        else:
            path = ""
            file_name = src
        if path not in files:
            files[path] = list()
        files[path].append(file_name)

    if deps:
        classpath_cmd = ":".join(["$(location " + x + ")" for x in deps])
        line = line + " --classpath=" + classpath_cmd

    cmd = []

    if debug:
        cmd.extend(["pwd", "set -x"])

    cmd.append("TMP=$$(mktemp -d || mktemp -d -t bazel-tmp)")

    for path in files:
        files_in_dir = " ".join([("$(location " + path + x + ")") for x in files[path]])
        cmd.extend([
            "mkdir -p $$TMP/" + package_path + path ,
            line + " " + files_in_dir + " -d " + "$$TMP/" + package_path + path,
        ])

    cmd.append(
        "$(JAVABASE)/bin/jar cf $(OUTS) -C $$TMP .",
    )

    if lombok_jar not in deps:
        deps = [lombok_jar] + deps

    if debug:
        print( cmd)

    native.genrule(
        name = name,
        srcs = srcs,
        outs = [name + ".srcjar"],
        cmd = " && ".join(cmd),
        tools = deps,
        toolchains = [toolchain],
        message = "Applying delombok to generate " + name,
    )
