variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC for the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group definitions"
  type = map(object({
    desired_size = number
    min_size     = number
    max_size     = number

    instance_types = list(string)
    capacity_type  = string
    disk_size      = number

    labels = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))

    tags = map(string)
  }))
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
