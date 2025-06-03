#!/bin/bash
set -e

# Actualiza el kubeconfig para conectarse al cluster
aws eks update-kubeconfig --region us-east-1 --name example-eks-cluster

# Espera a que el cluster esté listo
echo "Esperando a que el cluster esté listo..."
sleep 30

# Crea un namespace para NGINX
kubectl create namespace nginx-ingress --dry-run=client -o yaml | kubectl apply -f -

# Despliega NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/aws/deploy.yaml

# Espera a que los pods estén listos
echo "Esperando a que NGINX esté listo..."
kubectl wait --namespace nginx-ingress \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Crea un deployment de NGINX de ejemplo
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-example
  namespace: nginx-ingress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-example
  template:
    metadata:
      labels:
        app: nginx-example
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-example
  namespace: nginx-ingress
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: nginx-example
EOF

# Espera a que el servicio esté listo
echo "Esperando a que el servicio esté listo..."
sleep 30

# Muestra el estado del deployment y el servicio
echo "Estado del deployment de NGINX:"
kubectl get pods -n nginx-ingress
echo -e "\nEstado del servicio:"
kubectl get svc -n nginx-ingress

# Muestra la URL del Load Balancer
echo -e "\nURL del Load Balancer:"
kubectl get svc nginx-example -n nginx-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo 