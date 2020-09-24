load("@bazel_skylib//lib:paths.bzl", "paths")

HELM_CMD_PREFIX = """
echo "#!/usr/bin/env bash" > $@
cat $(location @com_github_deviavir_rules_helm//:runfiles_bash) >> $@
echo "export NAMESPACE=$$(grep NAMESPACE bazel-out/stable-status.txt | cut -d ' ' -f 2)" >> $@
echo "export BUILD_USER=$$(grep BUILD_USER bazel-out/stable-status.txt | cut -d ' ' -f 2)" >> $@
cat <<EOF >> $@
#export RUNFILES_LIB_DEBUG=1 # For runfiles debugging

export HELM=\$$(rlocation com_github_saidmasoud_rules_helm/helm)
PATH=\$$(dirname \$$HELM):\$$PATH
"""

def helm_chart(name, srcs, update_deps = False, repositories = None):
    """Defines a helm chart (directory containing a Chart.yaml).

    Args:
        name: A unique name for this rule.
        srcs: Source files to include as the helm chart. Typically this will just be glob(["**"]).
        update_deps: Whether or not to run a helm dependency update prior to packaging.
        repositories: A list of repositories to add and update to potentially be used as requirements/dependencies.
    """
    filegroup_name = name + "_filegroup"
    helm_cmd_name = name + "_package.sh"
    package_flags = ""
    repo_adds = []
    counter = 0
    if repositories:
        for repo in repositories:
            counter += 1
            repo_adds.append("$(location @com_github_deviavir_rules_helm//:helm) repo add bazel{} {}".format(counter, repo))
        repo_adds.append("$(location @com_github_deviavir_rules_helm//:helm) repo update")
    if update_deps:
        package_flags = "--dependency-update"
    native.filegroup(
        name = filegroup_name,
        srcs = srcs
    )
    native.genrule(
        name = name,
        srcs = [filegroup_name],
        outs = ["%s_chart.tar.gz" % name],
        tools = ["@com_github_deviavir_rules_helm//:helm"],
        cmd = """
# find Chart.yaml in the filegroup
CHARTLOC=missing
for s in $(SRCS); do
  if [[ $$s =~ .*Chart.yaml ]]; then
    CHARTLOC=$$(dirname $$s)
    break
  fi
done
export XDG_CACHE_HOME=".helm/cache"
export XDG_CONFIG_HOME=".helm/config"
export XDG_DATA_HOME=".helm/data"
mkdir -p .helm/cache .helm/config .helm/data
{repo_adds}
$(location @com_github_deviavir_rules_helm//:helm) package {package_flags} $$CHARTLOC
mv *tgz $@
rm -rf .helm
""".format(
            repo_adds = "\n".join(repo_adds),
            package_flags = package_flags
        )
    )

def _build_helm_set_args(values):
    set_args = ["--set=%s=%s" % (key, values[key]) for key in sorted((values or {}).keys())]
    return " ".join(set_args)

def _helm_cmd(cmd, args, name, helm_cmd_name, values_yaml = None, values = None):
    binary_data = ["@com_github_deviavir_rules_helm//:helm"]
    if values_yaml:
        binary_data.append(values_yaml)
    if values:
        args.append(_build_helm_set_args(values))

    native.sh_binary(
        name = name + "." + cmd,
        srcs = [helm_cmd_name],
        deps = ["@bazel_tools//tools/bash/runfiles"],
        data = binary_data,
        args = args
    )

def helm_release(name, release_name, chart, values_yaml = None, values = None, repository = None, version = None, namespace = ""):
    """Defines a helm release.

    A given target has the following executable targets generated:

    `(target_name).install`
    `(target_name).install.wait`
    `(target_name).status`
    `(target_name).delete`
    `(target_name).test`

    Args:
        name: A unique name for this rule.
        release_name: name of the release.
        chart: The chart defined by helm_chart.
        values_yaml: The values.yaml file to supply for the release.
        values: A map of additional values to supply for the release.
        repository: A URL to a repository to install $chart from.
        version: When pulling a chart from the $repository, which version should we install? Defaults to latest.
        namespace: The namespace to install the release into. If empty will default the NAMESPACE environment variable and will fall back the the current username (via BUILD_USER).
    """
    helm_cmd_name = name + "_run_helm_cmd.sh"
    genrule_srcs = ["@com_github_deviavir_rules_helm//:runfiles_bash"]

    # build --set params
    set_params = _build_helm_set_args(values)

    chartloc = "$(location {})".format(chart)

    set_version = ""

    repo_adds = []
    if repository:
        repo_name = "bazel1"
        chart_name = chart
        if len(chart.split("/")) > 1:
            repo_name = chart.split("/")[0]
            chart_name = chart.split("/")[1]
        repo_adds.append("helm repo add {} {}".format(repo_name, repository))
        repo_adds.append("helm repo update")
        chartloc = "{}/{}".format(repo_name, chart_name)
        if version:
            set_version = "--version {} ".format(version)
    else:
        genrule_srcs.append(chart)

    # build --values param
    values_param = ""
    if values_yaml:
        values_param = "-f $(location %s)" % values_yaml
        genrule_srcs.append(values_yaml)

    native.genrule(
        name = name,
        stamp = True,
        srcs = genrule_srcs,
        outs = [helm_cmd_name],
        cmd = HELM_CMD_PREFIX + """
export XDG_CACHE_HOME=".helm/cache"
export XDG_CONFIG_HOME=".helm/config"
export XDG_DATA_HOME=".helm/data"
mkdir -p .helm/cache .helm/config .helm/data
""" + "\n".join(repo_adds) + """
export CHARTLOC=""" + chartloc + """
EXPLICIT_NAMESPACE=""" + namespace + """
NAMESPACE=\$${EXPLICIT_NAMESPACE:-\$$NAMESPACE}
export NS=\$${NAMESPACE:-\$${BUILD_USER}}
if [ "\$$1" == "upgrade" ]; then
    helm \$$@ """ + release_name + " \$$CHARTLOC --namespace \$$NS " + set_version + "" + set_params + " " + values_param + """
else
    helm \$$@ """ + release_name + " --namespace \$$NS " + """
fi
rm -rf .helm
EOF"""
    )
    _helm_cmd("install", ["upgrade", "--install"], name, helm_cmd_name, values_yaml, values)
    _helm_cmd("install.wait", ["upgrade", "--install", "--wait"], name, helm_cmd_name, values_yaml, values)
    _helm_cmd("status", ["status"], name, helm_cmd_name)
    _helm_cmd("delete", ["delete"], name, helm_cmd_name)
    _helm_cmd("test", ["test"], name, helm_cmd_name)
