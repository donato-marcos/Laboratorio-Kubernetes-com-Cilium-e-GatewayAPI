
# Laboratório Kubernetes com Cilium e GatewayAPI

Este repositório documenta a implementação de um cluster Kubernetes robusto, utilizando **Cilium** como CNI (substituindo kube-proxy), **Gateway API** para gerenciamento de tráfego e uma stack completa de monitoramento com **Prometheus** e **Hubble**.

O ambiente simula uma topologia de produção com segregação de redes (WAN, Cluster, Storage) rodando sobre virtualização local.

## Ambiente de Hospedagem (Host)

*   **Sistema Operacional:** Fedora 43 (Workstation)
*   **Hypervisor:** KVM/QEMU
*   **Gerenciador:** Libvirt + Virt-Manager
*   **Provisionamento:** Terraform (via projeto modular externo)

---

## Especificações e Topologia de Rede

O cluster possui 3 nós Ubuntu Server. A identificação correta das interfaces de rede é crucial para a configuração do Cilium.

| Hostname | vCPU | vRAM | Interface WAN (`enp1s0`) | Interface Cluster (`enp2s0`) | Interface Storage (`enp3s0`) | Função |
| :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| `k8s-master01` | 2 | 2.5 GB | `192.168.200.10` | `172.16.200.10` | `172.16.201.10` | Control-Plane |
| `k8s-worker01` | 2 | 3.0 GB | `192.168.200.21` | `172.16.200.21` | `172.16.201.21` | Worker Node |
| `k8s-worker02` | 2 | 3.0 GB | `192.168.200.22` | `172.16.200.22` | `172.16.201.22` | Worker Node |

> **Nota de Rede:** O IP `192.168.200.9` será reservado para o **Cilium LoadBalancer**, atuando como VIP único para serviços externos. O anúncio L2 será feito na interface **`enp1s0`**.

---

## Provisionamento com Terraform (Opcional)

Se estiver usando `Libvirt+KVM`, pode usar o **[Projeto-Terraform-Libvirt-KVM](https://github.com/donato-marcos/Projeto-Terraform-Libvirt-KVM)** para automatizar a criação da infra.

### 1. Definição das Redes (`networks.auto.tfvars`)

```hcl
networks = [
  {
    name      = "k8s-wan"
    mode      = "nat"
    autostart = true
    ipv4_address      = "192.168.200.1"
    ipv4_prefix       = 24
    ipv4_dhcp_enabled = true
    ipv4_dhcp_start   = "192.168.200.64"
    ipv4_dhcp_end     = "192.168.200.128"
  },
  {
    name      = "k8s-cluster"
    mode      = "isolated"
    autostart = true
    ipv4_address      = "172.16.200.1"
    ipv4_prefix       = 24
    ipv4_dhcp_enabled = false
  },
  {
    name      = "k8s-storage"
    mode      = "isolated"
    autostart = true
    ipv4_address      = "172.16.201.1"
    ipv4_prefix       = 24
    ipv4_dhcp_enabled = false
  }
]
```

### 2. Definição das VMs (`vm.auto.tfvars`)

Note a ordem das redes definidas, que resulta nas interfaces `enp1s0`, `enp2s0` e `enp3s0` dentro das VMs.

```hcl
vms = {
  "k8s-master01" = {
    os_type        = "linux"
    vcpus          = 2
    current_memory = 2560
    memory         = 3072
    firmware       = "efi"
    video_model    = "virtio"
    graphics       = "spice"
    running        = true
    disks = [
      {
        name     = "os"
        size_gb  = 25
        bootable = true
        backing_store = {
          image  = "ubuntu-24-cloud.x86_64.qcow2"
          format = "qcow2"
        }
      }
    ]
    networks = [
      { name = "k8s-wan", ipv4_address = "192.168.200.10", ipv4_prefix = 24, ipv4_gateway = "192.168.200.1", dns_servers = ["192.168.200.1"] },
      { name = "k8s-cluster", ipv4_address = "172.16.200.10", ipv4_prefix = 24 },
      { name = "k8s-storage", ipv4_address = "172.16.201.10", ipv4_prefix = 24 }
    ]
  },
  "k8s-worker01" = {
    os_type        = "linux"
    vcpus          = 2
    current_memory = 2048
    memory         = 3072
    firmware       = "efi"
    video_model    = "virtio"
    graphics       = "spice"
    running        = true
    disks = [
      { name = "os", size_gb = 25, bootable = true, backing_store = { image = "ubuntu-24-cloud.x86_64.qcow2", format = "qcow2" } }
    ]
    networks = [
      { name = "k8s-wan", ipv4_address = "192.168.200.21", ipv4_prefix = 24, ipv4_gateway = "192.168.200.1", dns_servers = ["192.168.200.1"] },
      { name = "k8s-cluster", ipv4_address = "172.16.200.21", ipv4_prefix = 24 },
      { name = "k8s-storage", ipv4_address = "172.16.201.21", ipv4_prefix = 24 }
    ]
  },
  "k8s-worker02" = {
    os_type        = "linux"
    vcpus          = 2
    current_memory = 2048
    memory         = 3072
    firmware       = "efi"
    video_model    = "virtio"
    graphics       = "spice"
    running        = true
    disks = [
      { name = "os", size_gb = 25, bootable = true, backing_store = { image = "ubuntu-24-cloud.x86_64.qcow2", format = "qcow2" } }
    ]
    networks = [
      { name = "k8s-wan", ipv4_address = "192.168.200.22", ipv4_prefix = 24, ipv4_gateway = "192.168.200.1", dns_servers = ["192.168.200.1"] },
      { name = "k8s-cluster", ipv4_address = "172.16.200.22", ipv4_prefix = 24 },
      { name = "k8s-storage", ipv4_address = "172.16.201.22", ipv4_prefix = 24 }
    ]
  }
}
```

---

## Pré-requisitos e Configuração dos Nós

Execute em **todos os nós** (`master` e `workers`).

### 1. Configuração Inicial do SO

```bash
# 1. Definir Hostname
sudo hostnamectl hostname kube-master01    # Para o control-plane
sudo hostnamectl hostname kube-worker01    # Para o worker 1
sudo hostnamectl hostname kube-worker02    # Para o worker 2

# 2. Desativar Swap
sudo sed -i '/swap/d' /etc/fstab
sudo swapoff -a

# 3. Módulos do Kernel
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# 4. Sysctl para Rede
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
sudo sysctl --system | grep -E "forward|ip.*tables"
```

### 2. Instalação e Configuração do Containerd

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg gnupg bash-completion
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y containerd.io
sudo systemctl enable --now containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo grep "SystemdCgroup" /etc/containerd/config.toml
```

### 3. Instalação do Kubernetes (v1.35)

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

---

## Inicialização do Cluster

### 1. Control-Plane (`k8s-master01`)

Crie `kubeadm-config.yaml`:
```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.200.10
  bindPort: 6443
nodeRegistration:
  kubeletExtraArgs:
    - name: node-ip
      value: "172.16.200.10" # IP da interface cluster (enp2s0)
    - name: resolv-conf
      value: "/run/systemd/resolve/resolv.conf"
skipPhases:
  - addon/kube-proxy
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.35.1
controlPlaneEndpoint: 192.168.200.10:6443
networking:
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
apiServer:
  certSANs:
    - 192.168.200.10
etcd:
  local:
    dataDir: /var/lib/etcd
```

Inicialize:
```bash
sudo kubeadm init --config kubeadm-config.yaml
```
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
```bash
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
kubeadm completion bash | sudo tee /etc/bash_completion.d/kubeadm > /dev/null
sudo chmod a+r /etc/bash_completion.d/*
source ~/.bashrc
```

### 2. Worker Nodes

**No Master, gere o comando de join:**  
```bash
kubeadm token create --print-join-command
```
Execute o comando gerado nos workers. Alternativamente, use um arquivo join-config.yaml (lembrando de ajustar o node-ip para cada worker):

```bash
#join-config.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: 192.168.200.10:6443
    token: <TOKEN>
    caCertHashes:
      - sha256:<HASH>
nodeRegistration:
  kubeletExtraArgs:
    - name: node-ip
      value: "172.16.200.21" # altere o IP para os outros workers
    - name: resolv-conf
      value: "/run/systemd/resolve/resolv.conf"
```

## CNI Cilium, Gateway API e Load Balancing

> **Atenção à Interface:** Com base no ambiente pensado, a interface WAN é **`enp1s0`**. Esta será usada para o L2 Announcement.

### 1. Preparação (Helm, CLI e CRDs)

```bash
# Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
helm version

helm completion bash | sudo tee /etc/bash_completion.d/helm > /dev/null
sudo chmod a+r /etc/bash_completion.d/helm
source ~/.bashrc

# Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

cilium completion bash | sudo tee /etc/bash_completion.d/cilium > /dev/null
sudo chmod a+r /etc/bash_completion.d/cilium
source ~/.bashrc

# Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
```

### 2. Deploy do Cilium (Via Helm + Values)

Configurado para usar `enp1s0` como dispositivo principal para anúncios externos e `enp2s0` para roteamento nativo interno (se necessário ajustar, o Cilium detecta rotas, mas o `devices` deve apontar para a interface física de uplink geral ou específica para BPF).

Neste caso, como temos múltiplas interfaces, vamos definir `devices=enp1s0` para garantir que o LoadBalancer funcione na rede WAN, e o Cilium gerenciará o roteamento entre os pods.

Crie o arquivo `cilium-values.yaml`:
```yaml
# cilium-values.yaml
# --- Kubernetes API ---
k8sServiceHost: 192.168.200.10
k8sServicePort: 6443

# --- kube-proxy replacement ---
kubeProxyReplacement: true

# --- Datapath ---
devices:
  - enp1s0
  - enp2s0
routingMode: native
autoDirectNodeRoutes: true
ipv4NativeRoutingCIDR: 10.244.0.0/16

# --- IPAM ---
ipam:
  mode: cluster-pool
  operator:
    clusterPoolIPv4PodCIDRList: ["10.244.0.0/16"]
    clusterPoolIPv4MaskSize: 24

cluster:
  name: k8s-cluster
  id: 1

# --- L2 Announcements (substitui MetalLB) ---
l2announcements:
  enabled: true

externalIPs:
  enabled: true

loadBalancer:
  mode: snat
  l2:
    enabled: true

nodePort:
  enabled: true

# --- Gateway API (substitui ingress-nginx) ---
gatewayAPI:
  enabled: true

envoy:
  enabled: true

# --- Hubble ---
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
  metrics:
    enabled:
      - dns
      - drop
      - tcp
      - flow
      - port-distribution
      - http
      
# --- Observabilidade extra ---
prometheus:
  enabled: false

# --- Segurança ---
securityContext:
  capabilities:
    ciliumAgent:
      - NET_ADMIN
      - SYS_ADMIN
      - NET_RAW
      - IPC_LOCK
      - SYS_RESOURCE
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID

      
# --- Performance ---
bpf:
  masquerade: true
  hostRouting: true

enableIPv4Masquerade: true
enableIPv6: false
```

Instale o CNI Cilium:
```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
--version 1.19.1 \
--namespace kube-system \
-f cilium-values.yaml
```

Aguarde a instalação:
```bash
cilium status --wait
```

> **PODE DEMORAR BASTANTE**

### 3. Configuração do LoadBalancer L2 e Gateway

Crie o arquivo `l2-config.yaml`:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "wan-pool"
spec:
  blocks:
    - cidr: "192.168.200.9/32"
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: "wan-announcement-policy"
spec:
  nodeSelector:
    matchLabels:
      kubernetes.io/os: linux
  interfaces:
    - "^enp1s0$" # Anuncia o IP VIP apenas na interface WAN
  externalIPs: true
  loadBalancerIPs: true
```

Crie o arquivo `gateway.yaml`:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  annotations:
    io.cilium/lb-ipam-ips: 192.168.200.9 # Força o uso do IP reservado
spec:
  gatewayClassName: cilium
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
```

E aplique com:
```bash
kubectl apply -f gateway.yaml
```
---

## Monitoramento e Observabilidade

### 1. Metrics Server

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set "args={--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname}"
```
> **O Metrics-server é necessário para o HPA e VPA funcionar**

### 2. Hubble UI e Grafana

Crie `monitoring-routes.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: hubble-ui-route
  namespace: kube-system
spec:
  parentRefs:
  - name: my-gateway
    namespace: default
  hostnames:
  - "hubble.teste.local"
  rules:
  - backendRefs:
    - name: hubble-ui
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: monitoring-grafana-route
  namespace: monitoring
spec:
  parentRefs:
  - name: my-gateway
    namespace: default
  hostnames:
  - "grafana.teste.local"
  rules:
  - backendRefs:
    - name: monitoring-grafana
      port: 80
```
E aplique com:
```bash
kubectl apply -f monitoring-routes.yaml
```

Instale a stack Prometheus:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
--namespace monitoring \
--create-namespace \
--set grafana.adminPassword=alunofatec \
--set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
--set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false
```

### Acesso Local

No seu host Fedora, edite `/etc/hosts`:
```bash
echo "192.168.200.9 hubble.teste.local" | sudo tee -a /etc/hosts
echo "192.168.200.9 grafana.teste.local" | sudo tee -a /etc/hosts

```

Acesse:
*   **Hubble:** http://hubble.teste.local
*   **Grafana:** http://grafana.teste.local (admin / alunofatec)

---

## Validação Final

```bash
# Verificar se o Cilium está saudável
cilium status

# Verificar se o IP 192.168.200.9 foi atribuído ao Gateway
kubectl get gateway my-gateway

# Verificar serviços
kubectl get svc -n kube-system | grep cilium
kubectl get svc -n monitoring | grep grafana

# Testar conectividade interna
kubectl top nodes
```
