variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "site_id" {
  description = "Customer site identifier"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "video-analytics"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Adding an IP range for Management VLAN
variable "management_cidr" {
  description = "CIDR block for management VLAN"
  type = string
  default = "10.50.1.0/24"
    }

variable "general_node_instance_type" {
  description = "EC2 instance type for the general node group"
  type        = string
  default     = "m5.large"
}

variable "general_node_capacity_type" {
  description = "Capacity type for the general node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "general_node_min" {
  type        = number
  default     = 2
  description = "Minimum size for the general node group"
}

variable "general_node_desired" {
  type        = number
  default     = 3
  description = "Desired size for the general node group"
}

variable "general_node_max" {
  type        = number
  default     = 6
  description = "Maximum size for the general node group"
}

variable "gpu_node_instance_type" {
  description = "EC2 instance type for the GPU node group"
  type        = string
  default     = "g4dn.xlarge"
}

variable "gpu_node_capacity_type" {
  description = "Capacity type for the GPU node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "gpu_node_min" {
  type        = number
  default     = 1
  description = "Minimum size for the GPU node group"
}

variable "gpu_node_desired" {
  type        = number
  default     = 2
  description = "Desired size for the GPU node group"
}

variable "gpu_node_max" {
  type        = number
  default     = 5
  description = "Maximum size for the GPU node group"
}


# TODO: Add variables for:
# - Node group instance types and sizing
# - S3 bucket names
# - Any other configurable parameters your infrastructure needs
