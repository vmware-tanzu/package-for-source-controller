# Fluxcd-source-controller

The source-controller is a Kubernetes operator, specialised in artifacts acquisition
from external sources such as Git, Helm repositories and S3 buckets.
The source-controller implements the
[source.toolkit.fluxcd.io](https://github.com/fluxcd/source-controller/tree/master/docs/spec/v1beta1) API
and is a core component of the [GitOps toolkit](https://toolkit.fluxcd.io).

## Configuration

Source controller package has no configurable properties.

## Installation

To install FluxCD source-controller from the Tanzu Application Platform package repository:

1. List version information for the package by running:

    ```
    tanzu package available list fluxcd.source.controller.community.tanzu.vmware.com
    ```

    For example:

    ```
    $ tanzu package available list fluxcd.source.controller.community.tanzu.vmware.com
        \ Retrieving package versions for fluxcd.source.controller.tanzu.vmware.com...
          NAME                                                VERSION  RELEASED-AT
          fluxcd.source.controller.community.tanzu.vmware.com  0.21.2   2021-10-27 19:00:00 -0500 -05
    ```

2. Install the package by running:

    ```
    tanzu package install fluxcd-source-controller -p fluxcd.source.controller.community.tanzu.vmware.com -v VERSION-NUMBER
    ```

    Where:

    - `VERSION-NUMBER` is the version of the package listed in step 1.

    For example:

    ```
    tanzu package install fluxcd-source-controller -p fluxcd.source.controller.community.tanzu.vmware.com -v 0.21.2
    \ Installing package 'fluxcd.source.controller.community.tanzu.vmware.com'
    | Getting package metadata for 'fluxcd.source.controller.community.tanzu.vmware.com'
    | Creating service account 'fluxcd-source-controller-default-sa'
    | Creating cluster admin role 'fluxcd-source-controller-default-cluster-role'
    | Creating cluster role binding 'fluxcd-source-controller-default-cluster-rolebinding'
    | Creating package resource
    / Waiting for 'PackageInstall' reconciliation for 'fluxcd-source-controller'
    \ 'PackageInstall' resource install status: Reconciling


     Added installed package 'fluxcd-source-controller'
    ```

3. Verify the package install by running:

    ```
    tanzu package installed get fluxcd-source-controller
    ```

    For example:

    ```
    \ Retrieving installation details for fluxcd-source-controller...
    NAME:                    fluxcd-source-controller
    PACKAGE-NAME:            fluxcd.source.controller.community.tanzu.vmware.com
    PACKAGE-VERSION:         0.21.2
    STATUS:                  Reconcile succeeded
    CONDITIONS:              [{ReconcileSucceeded True  }]
    USEFUL-ERROR-MESSAGE:
    ```

    Verify that `STATUS` is `Reconcile succeeded`

    ```
    kubectl get pods -n flux-system
    ```

    For example:

    ```
    $ kubectl get pods -n flux-system
    NAME                                 READY   STATUS    RESTARTS   AGE
    source-controller-69859f545d-ll8fj   1/1     Running   0          3m38s
    ```

    Verify that `STATUS` is `Running`

## Documentation

For documentation specific to fluxcd-source-controller, check out the main repository
[fluxcd/source-controller](https://github.com/fluxcd/source-controller).
