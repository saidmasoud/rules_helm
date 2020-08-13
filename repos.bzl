load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

def helm_repositories():
    skylib_version = "0.8.0"
    http_archive(
        name = "bazel_skylib",
        type = "tar.gz",
        url = "https://github.com/bazelbuild/bazel-skylib/releases/download/{}/bazel-skylib.{}.tar.gz".format(skylib_version, skylib_version),
        sha256 = "2ef429f5d7ce7111263289644d233707dba35e39696377ebab8b0bc701f7818e",
    )

    http_archive(
        name = "helm",
        sha256 = "ff4ac230b73a15d66770a65a037b07e08ccbce6833fbd03a5b84f06464efea45",
        urls = ["https://get.helm.sh/helm-v3.3.0-linux-amd64.tar.gz"],
        build_file = "@com_github_deviavir_rules_helm//:helm.BUILD",
    )

    http_archive(
        name = "helm_osx",
        sha256 = "3399430b0fdfa8c840e77ddb4410d762ae64f19924663dbdd93bcd0e22704e0b",
        urls = ["https://get.helm.sh/helm-v3.3.0-darwin-amd64.tar.gz"],
        build_file = "@com_github_deviavir_rules_helm//:helm.BUILD",
    )
