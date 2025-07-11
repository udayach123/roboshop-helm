resource "null_resource" "kubeconfig" {
  triggers = {
    time = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOF
az login --service-principal --username $ARM_CLIENT_ID --password $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
az aks get-credentials --name ${var.name} --resource-group ${var.rg_name} --overwrite-existing
EOF
  }
}
resource "helm_release" "external-secrets" {
  depends_on = [
    null_resource.kubeconfig
  ]
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "devops"
  create_namespace = true
  set = [
    {
      name  = "server.service.type"
      value = "LoadBalancer"
    }
  ]
}

resource "null_resource" "external-secrets-secret-store" {
  depends_on = [
    helm_release.external-secrets
  ]

  triggers = {
    time = timestamp()
  }

  provisioner "local-exec" {
    command = <<TF
kubectl apply -f - <<KUBE
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: roboshop-${var.env}
spec:
  provider:
    vault:
      server: "http://vault.yourtherapist.in:8200"
      path: "roboshop-${var.env}"
      version: "v2"
      auth:
        tokenSecretRef:
          name: "vault-token"
          key: "token"
          namespace: devops
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
  namespace: devops
data:
  token: ${base64encode(var.token)}
  # token: aHZzLnZEbWVYeG9ONTcwWTQ2dGZxY2VhU2hpQg==
KUBE
TF
  }
}

resource "helm_release" "argocd" {
  depends_on = [
    null_resource.kubeconfig
  ]
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  set = [
    {
      name  = "server.service.type"
      value = "LoadBalancer"
    }
  ]
}
## Filebeat Helm Chart
resource "helm_release" "filebeat" {

  depends_on = [null_resource.kubeconfig]
  name       = "filebeat"
  repository = "https://helm.elastic.co"
  chart      = "filebeat"
  namespace  = "kube-system"
  wait       = "false"

  values = [
    file("${path.module}/helm-values/filebeat.yml")
  ]
}

## Prometheus Stack Helm Chart
resource "helm_release" "prometheus" {

  depends_on = [null_resource.kubeconfig]
  name       = "prom-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "devops"
  wait       = "false"

  values = [
    file("${path.module}/helm-values/prometheus.yml")
  ]
}

## Grafana  Helm Chart
resource "helm_release" "grafana" {
  depends_on = [null_resource.kubeconfig]
  name       = "grafana"
  namespace  = "devops"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "6.58.4" # Use a valid version from repo
  create_namespace = true

  values = [
    file("${path.module}/helm-values/grafana.yml")
  ]
}
## ELK  Helm Chart
# resource "helm_release" "elasticsearch" {
#   depends_on = [null_resource.kubeconfig]
#   name       = "elasticsearch"
#   namespace  = "devops"
#   repository = "https://helm.elastic.co"
#   chart      = "elasticsearch"
#   #version    = "8.13.4"
#   create_namespace = true
#
#   values = [file("${path.module}/helm-values/elk.yml")]
# }
#
# ## Kibana  Helm Chart
# resource "helm_release" "kibana" {
#   name       = "kibana"
#   namespace  = "devops"
#   repository = "https://helm.elastic.co"
#   chart      = "kibana"
#   #version    = "8.13.4"
#   create_namespace = true
#
#   values = [file("${path.module}/helm-values/kibana.yml")]
#   depends_on = [helm_release.elasticsearch]
# }
#
# ## Logstash  Helm Chart
# resource "helm_release" "logstash" {
#   name       = "logstash"
#   namespace  = "devops"
#   repository = "https://helm.elastic.co"
#   chart = "logstash"
#   #version    = "8.13.4"
#   create_namespace = true
#   values = [file("${path.module}/helm-values/logstash.yml")]
#   depends_on = [helm_release.kibana]
# }
