# Linux Kernel

### Base Requirements

  Cilium leverages and builds on the kernel eBPF functionality as well as various subsystems which integrate with eBPF. Therefore, host systems are required to run a recent Linux kernel to run a Cilium agent. More recent kernels may provide additional eBPF functionality that Cilium will automatically detect and use on agent start. For this version of Cilium, it is recommended to use kernel 5.10 or later (or equivalent such as 4.18 on RHEL 8.10). For a list of features that require newer kernels, see Required Kernel Versions for Advanced Features.

  In order for the eBPF feature to be enabled properly, the following kernel configuration options must be enabled. This is typically the case with distribution kernels. When an option can be built as a module or statically linked, either choice is valid.

    CONFIG_BPF=y
    CONFIG_BPF_EVENTS=y
    CONFIG_BPF_SYSCALL=y
    CONFIG_NET_CLS_BPF=y
    CONFIG_BPF_JIT=y
    CONFIG_NET_CLS_ACT=y
    CONFIG_NET_SCH_INGRESS=y
    CONFIG_CRYPTO_SHA1=y
    CONFIG_CRYPTO_USER_API_HASH=y
    CONFIG_CGROUPS=y
    CONFIG_CGROUP_BPF=y
    CONFIG_PERF_EVENTS=y
    CONFIG_SCHEDSTATS=y
    
### Requirements for Iptables-based Masquerading

  If you are not using BPF for masquerading (`enable-bpf-masquerade=false`, the default value), then you will need the following kernel configuration options.

    CONFIG_NETFILTER_XT_SET=m
    CONFIG_IP_SET=m
    CONFIG_IP_SET_HASH_IP=m
    CONFIG_NETFILTER_XT_MATCH_COMMENT=m
    
### Requirements for Tunneling and Routing

  Cilium uses tunneling protocols like VXLAN by default for pod-to-pod communication across nodes, as well as policy routing for various traffic management functionality. The following kernel configuration options are required for proper operation:

    CONFIG_VXLAN=y
    CONFIG_GENEVE=y
    CONFIG_FIB_RULES=y
    
> Note: On some embedded or custom Linux systems, especially when cross-compiling for ARM, enabling `CONFIG_FIB_RULES=y` directly in the kernel `.config` is not sufficient, as it depends on other routing-related kernel options to be enabled.
>
>The recommended approach is to use:
>```bash
>scripts/config --enable CONFIG_FIB_RULES
>make olddefconfig
>```
>The kernel build system uses `Kconfig` logic to validate and manage dependencies, so direct edits to `.config` may be ignored or silently overridden.

### Requirements for L7 and FQDN Policies

  L7 proxy redirection currently uses `TPROXY` iptables actions as well as `socket` matches. For L7 redirection to work as intended kernel configuration must include the following modules:

    CONFIG_NETFILTER_XT_TARGET_TPROXY=m
    CONFIG_NETFILTER_XT_TARGET_MARK=m
    CONFIG_NETFILTER_XT_TARGET_CT=m
    CONFIG_NETFILTER_XT_MATCH_MARK=m
    CONFIG_NETFILTER_XT_MATCH_SOCKET=m
    
  When `xt_socket` kernel module is missing the forwarding of redirected L7 traffic does not work in non-tunneled datapath modes. Since some notable kernels (e.g., COS) are shipping without `xt_socket` module, Cilium implements a fallback compatibility mode to allow L7 policies and visibility to be used with those kernels. Currently this fallback disables `ip_early_demux` kernel feature in non-tunneled datapath modes, which may decrease system networking performance. This guarantees HTTP and Kafka redirection works as intended. However, if HTTP or Kafka enforcement policies are never used, this behavior can be turned off by adding the following to the helm configuration command line:

```bash
helm install cilium cilium/cilium --version 1.19.4 \
   --namespace kube-system \
   ... \
   --set enableXTSocketFallback=false
```

### Requirements for IPsec

  The IPsec Transparent Encryption feature requires a lot of kernel configuration options, most of which to enable the actual encryption. Note that the specific options required depend on the algorithm. The list below corresponds to requirements for GCM-128-AES.

     CONFIG_XFRM=y
     CONFIG_XFRM_OFFLOAD=y
     CONFIG_XFRM_STATISTICS=y
     CONFIG_XFRM_ALGO=m
     CONFIG_XFRM_USER=m
     CONFIG_INET{,6}_ESP=m
     CONFIG_INET{,6}_IPCOMP=m
     CONFIG_INET{,6}_XFRM_TUNNEL=m
     CONFIG_INET{,6}_TUNNEL=m
     CONFIG_INET_XFRM_MODE_TUNNEL=m
     CONFIG_CRYPTO_AEAD=m
     CONFIG_CRYPTO_AEAD2=m
     CONFIG_CRYPTO_GCM=m
     CONFIG_CRYPTO_SEQIV=m
     CONFIG_CRYPTO_CBC=m
     CONFIG_CRYPTO_HMAC=m
     CONFIG_CRYPTO_SHA256=m
     CONFIG_CRYPTO_AES=m
     
### Requirements for the Bandwidth Manager

  The Bandwidth Manager requires the following kernel configuration option to change the packet scheduling algorithm.

    CONFIG_NET_SCH_FQ=m
    
### Requirements for Netkit Device Mode

  The netkit device mode requires the following kernel configuration option to create netkit devices.

    CONFIG_NETKIT=y
