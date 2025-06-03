variable "vpc_id" {
  description = "ID of the VPC where the bastion host will be created"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet where the bastion host will be created"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster to connect to"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
} 