# EKS Cluster con NGINX Ingress

Este proyecto despliega un cluster EKS en AWS con NGINX Ingress Controller y un ejemplo de aplicación NGINX expuesta a través de un Network Load Balancer.

## Requisitos

- AWS CLI configurado con credenciales válidas
- kubectl instalado
- Terraform >= 1.0.0

## Estructura

```
.
├── main.tf              # Configuración principal de Terraform
├── deploy_nginx.sh      # Script para desplegar NGINX
└── README.md           # Este archivo
```

## Uso

1. Inicializar Terraform:
```bash
terraform init
```

2. Revisar el plan:
```bash
terraform plan
```

3. Aplicar la configuración:
```bash
terraform apply
```

4. Para destruir la infraestructura:
```bash
terraform destroy
```

## Características

- Cluster EKS con versión 1.27
- Nodo worker t3.micro (SPOT) para minimizar costos
- VPC con 2 zonas de disponibilidad
- NGINX Ingress Controller
- Ejemplo de aplicación NGINX expuesta a través de NLB

## Costos

Este setup está optimizado para minimizar costos:
- Uso de instancias SPOT
- Tamaño mínimo de nodo (t3.micro)
- Un solo nodo worker
- 2 zonas de disponibilidad
- Un solo NAT Gateway

## Notas

- El script `deploy_nginx.sh` se ejecuta automáticamente después de crear el cluster
- La URL del Load Balancer se mostrará al final de la ejecución
- Los recursos se crean en la región us-east-1 