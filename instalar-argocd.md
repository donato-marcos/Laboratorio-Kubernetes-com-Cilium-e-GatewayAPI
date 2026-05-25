># Instalação do Argo CD

## 1. Instalar os Manifestos no Cluster
```bash
cat > argocd-values.yaml << 'EOF'
# argocd-values.yaml
configs:
  params:
    server.insecure: "true"

  cm:
    kustomize.buildOptions: "--enable-helm"
    admin.enabled: true
    application.instanceLabelKey: argocd.argoproj.io/instance

  secret:
    createSecret: true
    argocdServerAdminPassword: "$2a$10$ELkUwC1ks63C8FTgD5sn/e1maUYfujHxkv6dt4fl/sgaNbSiWw/Um"
    argocdServerAdminPasswordMtime: "2026-05-24T15:04:05Z"
EOF
```
> "$2a$10$ELkUwC1ks63C8FTgD5sn/e1maUYfujHxkv6dt4fl/sgaNbSiWw/Um" é Hash de **alunofatec**

```bash
helm install argocd \
  oci://ghcr.io/argoproj/argo-helm/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f argocd-values.yaml
```

## 3. Criar a Rota de Acesso (Gateway API)
Aplique o manifesto abaixo para expor a interface web pelo domínio configurado:
```bash
cat > argocd-httproute.yaml << 'EOF'
#argocd-httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd-server-route
  namespace: argocd
spec:
  parentRefs:
  - name: public-gateway-ipv4
    namespace: default
  hostnames:
  - "argocd.aesthar.com.br"
  rules:
  - backendRefs:
    - name: argocd-server
      port: 80
EOF
```
```bash
kubectl apply -f argocd-httproute.yaml
```
## 4. Instalar o Argo CD CLI
```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

## 5. Configurar Autocomplete do Bash (Opcional)
```bash
argocd completion bash | sudo tee /etc/bash_completion.d/argocd > /dev/null
sudo chmod a+r /etc/bash_completion.d/argocd
source ~/.bashrc
```

## 6. Efetuar o Login via CLI
```bash
argocd login argocd.aesthar.com.br:80 --username admin --password alunofatec --insecure
```

## 7. GitOps
Foi criado o repositório https://github.com/donato-marcos/k8s-configs com a intenção de automatizar alguns recursos.