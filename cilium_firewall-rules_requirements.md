# Firewall Rules

  If you are running Cilium in an environment that requires firewall rules to enable connectivity, you will have to add the following rules to ensure Cilium works properly.

  It is recommended but optional that all nodes running Cilium in a given cluster must be able to ping each other so `cilium-health` can report and monitor connectivity among nodes. This requires ICMP Type 0/8, Code 0 open among all nodes. TCP 4240 should also be open among all nodes for `cilium-health` monitoring. Note that it is also an option to only use one of these two methods to enable health monitoring. If the firewall does not permit either of these methods, Cilium will still operate fine but will not be able to provide health information.

  For IPsec enabled Cilium deployments, you need to ensure that the firewall allows ESP traffic through. For example, AWS Security Groups doesn’t allow ESP traffic by default.

  If you are using WireGuard, you must allow UDP port 51871.

  If you are using VXLAN overlay network mode, Cilium uses Linux’s default VXLAN port 8472 over UDP, unless Linux has been configured otherwise. In this case, UDP 8472 must be open among all nodes to enable VXLAN overlay mode. The same applies to Geneve overlay network mode, except the port is UDP 6081.

  If you are running in direct routing mode, your network must allow routing of pod IPs.

  As an example, if you are running on AWS with VXLAN overlay networking, here is a minimum set of AWS Security Group (SG) rules. It assumes a separation between the SG on the master nodes, `master-sg`, and the worker nodes, `worker-sg`. It also assumes `etcd` is running on the master nodes.

  Master Nodes (``master-sg``) Rules:

  | Port Range / Protocal | Ingress/Egress | Source/Destination | Description |
  | --- | --- | --- | --- |
  | 2379-2380/tcp | ingress | `worker-sg` | etcd access |
  | 8472/udp | ingress | `master-sg` (self) | VXLAN overley |
  | 8472/udp | ingress | `worker-sg` | VXLAN overlay |
  | 4240/tcp | ingress | `master-sg` (self) | health checks |
  | 4240/tcp | ingress | `worker-sg` | health checks |
  | ICMP 8/0 | ingress | `master-sg` (self) | health checks |
  | ICMP 8/0 | ingress | `worker-sg` | health checks |
  | 8472/udp | egress | `master-sg` (self) | VXLAN overley |
  | 8472/udp | egress | `worker-sg` | VXLAN overlay |
  | 4240/tcp | egress | `master-sg` (self) | health checks |
  | 4240/tcp | egress | `worker-sg` | health checks |
  | ICMP 8/0 | egress | `master-sg` (self) | health checks |
  | ICMP 8/0 | egress | `worker-sg` | health checks |
  
  Worker Nodes (`worker-sg`):
  
  | Port Range / Protocal | Ingress/Egress | Source/Destination | Description |
  | --- | --- | --- | --- |
  | 8472/udp | ingress | `master-sg` | VXLAN overley |
  | 8472/udp | ingress | `worker-sg` (self) | VXLAN overlay |
  | 4240/tcp | ingress | `master-sg` | health checks |
  | 4240/tcp | ingress | `worker-sg` (self) | health checks |
  | ICMP 8/0 | ingress | `master-sg` | health checks |
  | ICMP 8/0 | ingress | `worker-sg` (self) | health checks |
  | 8472/udp | egress | `master-sg` | VXLAN overley |
  | 8472/udp | egress | `worker-sg` (self) | VXLAN overlay |
  | 4240/tcp | egress | `master-sg` | health checks |
  | 4240/tcp | egress | `worker-sg` (self) | health checks |
  | ICMP 8/0 | egress | `master-sg` | health checks |
  | ICMP 8/0 | egress | `worker-sg` (self) | health checks |
  | 2379-2380/tcp | ingress | `worker-sg` | etcd access |
  
  > Note: If you use a shared SG for the masters and workers, you can condense these rules into ingress/egress to self. If you are using Direct Routing mode, you can condense all rules into ingress/egress ANY port/protocol to/from self.

  The following ports should also be available on each node:

| Port Range / Protocol | Description |
| --- | --- |
| 4240/tcp | cluster health checks (cilium-health) |
| 4244/tcp | Hubble server |
| 4245/tcp | Hubble Relay |
| 4250/tcp | Mutual Authentication port |
| 4251/tcp | Spire Agent health check port (listening on 127.0.0.1 or ::1) |
| 6060/tcp | cilium-agent pprof server (listening on 127.0.0.1) |
| 6061/tcp | cilium-operator pprof server (listening on 127.0.0.1) |
| 6062/tcp | Hubble Relay pprof server (listening on 127.0.0.1) |
| 9878/tcp | cilium-envoy health listener (listening on 127.0.0.1) |
| 9879/tcp | cilium-agent health status API (listening on 127.0.0.1 and/or ::1) |
| 9890/tcp | cilium-agent gops server (listening on 127.0.0.1) |
| 9891/tcp | operator gops server (listening on 127.0.0.1) |
| 9893/tcp | Hubble Relay gops server (listening on 127.0.0.1) |
| 9901/tcp | cilium-envoy Admin API (listening on 127.0.0.1) |
| 9962/tcp | cilium-agent Prometheus metrics |
| 9963/tcp | cilium-operator Prometheus metrics |
| 9964/tcp | cilium-envoy Prometheus metrics |
| 51871/udp | WireGuard encryption tunnel endpoint |