TANZU_CLI_TARBALL="tanzu-framework-release/tanzu-framework-linux-amd64.tar.gz"
KAPP_RELEASE="kapp-controller-release/release.yml"
SECRETGEN_RELEASE="secretgen-controller-release/release.yml"

# extracts and installs the necessary plugins for tap
install_tanzu_cli() {
  mkdir /tmp/tanzu
  tar -zxvf $TANZU_CLI_TARBALL -C /tmp/tanzu > /dev/null

  pushd /tmp/tanzu > /dev/null
    install cli/core/*/tanzu-core-linux_amd64 /usr/local/bin/tanzu
    tanzu config set features.global.context-aware-cli-for-plugins false
    tanzu plugin install --local cli secret > /dev/null
    tanzu plugin install --local cli package > /dev/null
  popd > /dev/null
}

# install kapp controller and secretgen controller, the prereqs for any tap
# operations. Requires $TANZU_CLI_TARBALL, $KAPP_RELEASE, $SECRETGEN_RELEASE to
# be accessible from the current working directory
install_prereqs() {
  local user=$1
  local pass=$2

  if [ ! -f $TOOLS_DIR/kapp ]; then
    install_kapp
  fi

  echo "Installing prereqs"
  kapp deploy -a kapp-controller -f $KAPP_RELEASE -y > /dev/null
  kapp deploy -a secretgen-controller -f $SECRETGEN_RELEASE -y > /dev/null

  install_tanzu_cli
  _tanzu secret registry add tap-registry --username "$user" --password "$pass" --server dev.registry.tanzu.vmware.com --export-to-all-namespaces --yes
}

# installs the PackageMetadata, Package, and then installs the package.
# Requires tap-packages repo to be accessible from current working directory
install_package() {
  local package=$1
  local package_name=$2
  local version=$3

  kubectl apply -f "tce-packages/packages/$package/metadata.yaml" -f "tce-packages/packages/$package/$version/package.yaml"
  _tanzu package install "$package" --package-name "$package_name" --version $version
}

# deletes the specified package
delete_package() {
  local package=$1

  _tanzu package installed delete "$package" --yes
}

# upgrades a package in place
upgrade_package() {
  local package=$1
  local package_name=$2
  local version=$3

  _tanzu package installed update "$package" --package-name "$package_name" --version "$version"
}

# extract the version of a package from the tap-pkg package (i.e. the one bundled with current version of tap)
version_from_tap() {
  local package_yaml=$1

  if [ ! -f $TOOLS_DIR/yq ]; then
    install_yq
  fi

  yq e '.spec.packageRef.versionSelection.constraints' "tap-packages/tap-pkg/config/$package_yaml"
}

# extract the version of a package from its semver (i.e. v1.2.3 -> 1.2.3)
version_from_semver() {
  echo $1 | tr -d 'v'
}

# extract the image name (and sha) from an image url
image_from_url() {
  local image=$1

  local parts=(${image//\// }) # replace '/' with ' ' and parse into array
  local len=${#parts[@]}
  echo ${parts[$len - 1]}
}

# extract the registry from an image url
registry_from_url() {
  local image=$1

  local parts=(${image//\// }) # replace '/' with ' ' and parse into array
  local len=${#parts[@]}
  echo ${parts[0]}
}

# creates a dir for any required tools to be installed to
setup_tools() {
  export TOOLS_DIR="/tmp/tools"
  mkdir "$TOOLS_DIR"
  export PATH="$PATH:$TOOLS_DIR"
}

install_ytt() {
  chmod +x ytt-release/ytt-linux-amd64 && mv ytt-release/ytt-linux-amd64 "$TOOLS_DIR/ytt"
}

install_kapp() {
  chmod +x kapp-release/kapp-linux-amd64 && mv kapp-release/kapp-linux-amd64 "$TOOLS_DIR/kapp"
}

install_kbld() {
  chmod +x kbld-release/kbld-linux-amd64 && mv kbld-release/kbld-linux-amd64 "$TOOLS_DIR/kbld"
}

install_imgpkg() {
  chmod +x imgpkg-release/imgpkg-linux-amd64 && mv imgpkg-release/imgpkg-linux-amd64 "$TOOLS_DIR/imgpkg"
}

install_grype() {
  tar -xzf grype-release/grype_*_linux_amd64.tar.gz -C "$TOOLS_DIR" grype && chmod +x "$TOOLS_DIR/grype"
}

install_yq() {
  chmod +x yq-release/yq_linux_amd64 && mv yq-release/yq_linux_amd64 "$TOOLS_DIR/yq"
}

install_crane() {
  tar -xzf crane-release/go-containerregistry_Linux_x86_64.tar.gz -C "$TOOLS_DIR" && chmod +x "$TOOLS_DIR/crane"
}

# the tanzu cli makes use of spinners, which don't render very nicely in the build output
# the solution is to trick the tanzu cli into thinking it's getting piped, in which case no spinners will be used
# XXX: revisit this after runway upgrades to Concourse 7.x as there's a PR that improves ansi parsing
_tanzu() {
  tanzu $@ | cat
}

setup_tools
