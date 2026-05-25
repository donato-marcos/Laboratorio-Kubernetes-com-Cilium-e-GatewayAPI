# Privileges

The following privileges are required to run Cilium. When running the standard Kubernetes DaemonSet, the privileges are automatically granted to Cilium.

  - Cilium interacts with the Linux kernel to install eBPF program which will then perform networking tasks and implement security rules. In order to install eBPF programs system-wide, `CAP_SYS_ADMIN` privileges are required. These privileges must be granted to `cilium-agent`.

    The quickest way to meet the requirement is to run `cilium-agent` as root and/or as privileged container.

  - Cilium requires access to the host networking namespace. For this purpose, the Cilium pod is scheduled to run in the host networking namespace directly.