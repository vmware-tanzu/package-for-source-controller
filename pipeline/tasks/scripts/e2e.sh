#!/usr/bin/env bash

set -eoux pipefail

CREATE_CLUSTER="${CREATE_CLUSTER:-true}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"
LOAD_IMG_INTO_KIND="${LOAD_IMG_INTO_KIND:-true}"
BUILD_PLATFORM="${BUILD_PLATFORM:-linux/amd64}"
MINIO_HELM_VER="${MINIO_HELM_VER:-v6.3.1}"
# Older tags do not bundle multiple architectures. Newer tags are 5-6 times larger.
MINIO_TAG="${MINIO_TAG:-RELEASE.2020-09-17T04-49-20Z}"

IMG=test/source-controller
TAG=latest

MC_RELEASE=mc.RELEASE.2021-12-16T23-38-39Z
MC_AMD64_SHA256=d14302bbdaa180a073c1627ff9fbf55243221e33d47e32df61a950f635810978
MC_ARM64_SHA256=00791995bf8d102e3159e23b3af2f5e6f4c784fafd88c60161dcf3f0169aa217

ROOT_DIR="$(git rev-parse --show-toplevel)"
BUILD_DIR="${ROOT_DIR}/build"

source ${ROOT_DIR}/hack/_helpers.sh

install_prereqs 'robot$runway' 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE2MzgzMDU5MTUsImlzcyI6ImhhcmJvci10b2tlbi1kZWZhdWx0SXNzdWVyIiwiaWQiOjE2MjEzNDMsInBpZCI6MjMwLCJhY2Nlc3MiOlt7IlJlc291cmNlIjoiL3Byb2plY3QvMjMwL3JlcG9zaXRvcnkiLCJBY3Rpb24iOiJwdXNoIiwiRWZmZWN0IjoiIn0seyJSZXNvdXJjZSI6Ii9wcm9qZWN0LzIzMC9oZWxtLWNoYXJ0IiwiQWN0aW9uIjoicmVhZCIsIkVmZmVjdCI6IiJ9LHsiUmVzb3VyY2UiOiIvcHJvamVjdC8yMzAvaGVsbS1jaGFydC12ZXJzaW9uIiwiQWN0aW9uIjoiY3JlYXRlIiwiRWZmZWN0IjoiIn1dfQ.a-2CU4d9rnCeygT-NGiApV8AEiFdYyM34nFcvJteqb8kLO-TT9I8Oc4kdeq5K-UWiIWOr-kWpr3Aa9VMPQ4Q4UedWXUKT6EMkq7iGrxcMDfQEsnsBrShwamGPvETKQFxmlO5WSzNUE6oBw6VNETjE2sb6qo7TB-ItxVGQtfFBulkBYD88INmMdMb4dG6yT3O8buXdKzuOyXeV0M846BsYJ9nuQ5Fv4TV2ADoFdhL0btVExefHNTnjzDPogWxogxQKnlf-o031mbB1ALmB3HJLD6Ys2fLBmF-Pi3oN8rQWctX8cH9NDeFBAl9VhXY4vxsJc2IwklJestaiIjKmhF3-BqZxjdI66K89Mz_w9A7niy6qLcg2m7rLNYzdb5pdJrD9dxxwEK6iMFtpowtH0AI-wW3cj4vZfQnaEVDK_7oaxXHtwU-Nd_pmMSSAYcU51B5ETMKLO6EgznBkRyi_eGPfnQAywjdIx4M5qCVTLWBkXin_fxZICSZ48mg8LMlfp_mevqzTaJ2lSaERl36Uc-x8H_Fydre2otw2C1eOTBmQ5j-5-TeUtIcjaa7HgK7nZLlCeYVlb2QZ0WX3k2fSODaF6lA2yvavekiHfkuKuZNQDmPSCMdW04NLb6AeBVjZehMVsPAZuTLTn_wMSIF4LntS9Ge0g7itW4qhPqLXV4aL7A'

new_version="0.16.1"

echo "Testing Install"
install_package "fluxcd-source-controller" "fluxcd.source.controller.tanzu.vmware.com" $new_version

# if "${CREATE_CLUSTER}"; then
#     KIND_CLUSTER_NAME="flux-${RANDOM}"
#     export KUBECONFIG="${ROOT_DIR}/build/kindconfig"
#
#     echo "Spinning up flux kind cluster"
#     kind create cluster --name "${KIND_CLUSTER_NAME}" --kubeconfig "${KUBECONFIG}"
# fi

function cleanup(){
    EXIT_CODE="$?"

    # only dump all logs if an error has occurred
    if [ ${EXIT_CODE} -ne 0 ]; then
        kubectl -n kube-system describe pods
        kubectl -n source-system describe pods
        kubectl -n source-system get gitrepositories -oyaml
        kubectl -n source-system get helmrepositories -oyaml
        kubectl -n source-system get helmcharts -oyaml
        kubectl -n source-system get all
        kubectl -n source-system logs deploy/source-controller
        kubectl -n minio get all
        kubectl -n minio describe pods
    else
        echo "All E2E tests passed!"
    fi

    if "${CREATE_CLUSTER}"; then
        echo "Delete cluster"
        kind delete cluster --name "${KIND_CLUSTER_NAME}"
    fi
    exit ${EXIT_CODE}
}
trap cleanup EXIT

# Wait for nodes to be ready and pods to be running
kubectl wait node "${KIND_CLUSTER_NAME}-control-plane" --for=condition=ready --timeout=2m
kubectl wait --for=condition=ready -n kube-system -l k8s-app=kube-dns pod
kubectl wait --for=condition=ready -n local-path-storage -l app=local-path-provisioner pod

# echo "Build, load image into kind and deploy controller"
# make docker-build IMG="${IMG}" TAG="${TAG}" BUILD_PLATFORMS="${BUILD_PLATFORM}" BUILD_ARGS=--load
#
# if "${LOAD_IMG_INTO_KIND}"; then
#     kind load docker-image --name "${KIND_CLUSTER_NAME}" "${IMG}":"${TAG}"
# fi

# make dev-deploy IMG="${IMG}" TAG="${TAG}"

echo "Run smoke tests"
kubectl -n source-system apply -f "ci/config/samples"
kubectl -n source-system rollout status deploy/source-controller --timeout=1m
kubectl -n source-system wait gitrepository/gitrepository-sample --for=condition=ready --timeout=1m
kubectl -n source-system wait helmrepository/helmrepository-sample --for=condition=ready --timeout=1m
kubectl -n source-system wait helmchart/helmchart-sample --for=condition=ready --timeout=1m
kubectl -n source-system delete -f "ci/config/samples"

echo "Run HelmChart values file tests"
kubectl -n source-system apply -f "ci/config/testdata/helmchart-valuesfile"
kubectl -n source-system wait helmchart/podinfo --for=condition=ready --timeout=5m
kubectl -n source-system wait helmchart/podinfo-git --for=condition=ready --timeout=5m
kubectl -n source-system delete -f "ci/config/testdata/helmchart-valuesfile"

echo "Setup Minio"
kubectl create ns minio
helm repo add minio https://helm.min.io/ --force-update
helm upgrade minio minio/minio --wait -i \
    --version "${MINIO_HELM_VER}" \
    --namespace minio \
    --set accessKey=myaccesskey \
    --set secretKey=mysecretkey \
    --set resources.requests.memory=128Mi \
    --set persistence.enable=false \
    --set image.tag="${MINIO_TAG}"
kubectl -n minio port-forward svc/minio 9000:9000 &>/dev/null &

sleep 2

if [ ! -f "${BUILD_DIR}/mc" ]; then
    MC_SHA256="${MC_AMD64_SHA256}"
    ARCH="amd64"
    if [ "${BUILD_PLATFORM}" = "linux/arm64" ]; then
        MC_SHA256="${MC_ARM64_SHA256}"
        ARCH="arm64"
    fi

    mkdir -p "${BUILD_DIR}"
    curl -o "${BUILD_DIR}/mc" -LO "https://dl.min.io/client/mc/release/linux-${ARCH}/archive/${MC_RELEASE}"
    if ! echo "${MC_SHA256}  ${BUILD_DIR}/mc" | sha256sum --check; then
        echo "Checksum failed for mc."
        rm "${BUILD_DIR}/mc"
        exit 1
    fi

    chmod +x "${BUILD_DIR}/mc"
fi

"${BUILD_DIR}/mc" alias set minio http://localhost:9000 myaccesskey mysecretkey --api S3v4
kubectl -n source-system apply -f "ci/config/testdata/minio/secret.yaml"

echo "Run Bucket tests"
"${BUILD_DIR}/mc" mb minio/podinfo
"${BUILD_DIR}/mc" mirror "ci/config/testdata/minio/manifests/" minio/podinfo

kubectl -n source-system apply -f "ci/config/testdata/bucket/source.yaml"
kubectl -n source-system wait bucket/podinfo --for=condition=ready --timeout=1m


echo "Run HelmChart from Bucket tests"
"${BUILD_DIR}/mc" mb minio/charts
"${BUILD_DIR}/mc" mirror "ci/controllers/testdata/charts/helmchart/" minio/charts/helmchart

kubectl -n source-system apply -f "ci/config/testdata/helmchart-from-bucket/source.yaml"
kubectl -n source-system wait bucket/charts --for=condition=ready --timeout=1m
kubectl -n source-system wait helmchart/helmchart-bucket --for=condition=ready --timeout=1m

echo "Run large Git repo tests"
kubectl -n source-system apply -f "ci/config/testdata/git/large-repo.yaml"
kubectl -n source-system wait gitrepository/large-repo-go-git --for=condition=ready --timeout=2m15s
kubectl -n source-system wait gitrepository/large-repo-libgit2 --for=condition=ready --timeout=2m15s
