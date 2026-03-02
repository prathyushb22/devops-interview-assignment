# main.tf — EKS Cluster and Node Groups
#
# TASK: Complete this file to create a production-grade EKS cluster.
# Requirements:
#   - EKS cluster with proper IAM roles
#   - At least two node groups: one for general workloads, one for GPU inference
#   - Proper subnet placement (private subnets for nodes)
#   - Reference security groups from networking.tf

# --- EKS Cluster IAM Role ---
# TODO: Create an IAM role for the EKS cluster with the AmazonEKSClusterPolicy

# Creating the trust policy for IAM role
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# Allowing EKS service to assume this role
resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

# Setting minimum permissions to run an EKS Cluster
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Allowing EKS Cluster to manage VPC Related resources
resource "aws_iam_role_policy_attachment" "eks_cluster_vpc_controller" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}


# --- EKS Cluster ---
# TODO: Create the EKS cluster resource
#   - Place in private subnets
#   - Enable cluster logging (api, audit, authenticator)
#   - Reference the cluster IAM role

# Creates an AWS Cloudwatch Log group to hold EKS Control plane logs
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30
}

# Creates EKS Cluster resourcein private subnets with logging enabled and IAM role assigned
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = [aws_subnet.private_a.id,aws_subnet.private_b.id,]

    security_group_ids = [aws_security_group.eks_nodes.id]

    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_cluster_vpc_controller,
    aws_cloudwatch_log_group.eks_cluster,
  ]
}


# --- Node Group IAM Role ---
# TODO: Create an IAM role for EKS node groups with:
#   - AmazonEKSWorkerNodePolicy
#   - AmazonEKS_CNI_Policy
#   - AmazonEC2ContainerRegistryReadOnly

data "aws_iam_policy_document" "eks_nodes_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Create IAM role for EKS node groups and allow EC2 service to assume this role
resource "aws_iam_role" "eks_nodes" {
  name               = "${var.cluster_name}-eks-nodes-role"
  assume_role_policy = data.aws_iam_policy_document.eks_nodes_assume_role.json
}

# Gives permission to join and operate as EKS Workers
resource "aws_iam_role_policy_attachment" "eks_nodes_worker" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Allows CNI to call EC2 APIs to manage pod networking
resource "aws_iam_role_policy_attachment" "eks_nodes_cni" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Lets nodes pull from ECR
resource "aws_iam_role_policy_attachment" "eks_nodes_ecr" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- Add-ons (baseline) ---
# Core cluster components that are needed
# Installs the VPC CNI plugin
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  depends_on = [aws_eks_cluster.main]
}

# Installs CoreDNS which provides the cluster DNS
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  depends_on = [aws_eks_cluster.main]
}

# Kube-proxy handles kubernetes networking
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  depends_on = [aws_eks_cluster.main]
}


# --- General Node Group ---
# TODO: Create a managed node group for general workloads
#   - Instance type(s) appropriate for general workloads
#   - Scaling configuration (min, max, desired)
#   - Place in private subnets

# Creates a node group for general workloads with the instance types and scaling configs defined in variables
resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-general"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  
  subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  instance_types = [var.general_node_instance_type]
  capacity_type  = var.general_node_capacity_type

  scaling_config {
    desired_size = var.general_node_desired
    max_size     = var.general_node_max
    min_size     = var.general_node_min
  }

  labels = {
    workload = "general"
  }

  update_config {
  max_unavailable_percentage = 25
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes_worker,
    aws_iam_role_policy_attachment.eks_nodes_cni,
    aws_iam_role_policy_attachment.eks_nodes_ecr,
  ]
}

# --- GPU Node Group ---
# TODO: Create a managed node group for GPU inference
#   - GPU instance type (e.g., g4dn.xlarge)
#   - Appropriate scaling
#   - Taints for GPU workload isolation
#   - Place in private subnets

# Creates a node group for GPU workloads with the instance types and scaling configs defined in variables
# The taint section is required to ensure these nodes are reserved for pods that match the taint (GPU Workloads)
# Prevents scheduling general workloads on these nodes
resource "aws_eks_node_group" "gpu" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-gpu"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  
  subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  instance_types = [var.gpu_node_instance_type]
  capacity_type  = var.gpu_node_capacity_type

  scaling_config {
    desired_size = var.gpu_node_desired
    max_size     = var.gpu_node_max
    min_size     = var.gpu_node_min
  }

  labels = {
    workload = "gpu"
  }

  taint {
    key    = "nvidia.com/gpu"
    value  = "present"
    effect = "NO_SCHEDULE"
  }

  update_config {
  max_unavailable_percentage = 25
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes_worker,
    aws_iam_role_policy_attachment.eks_nodes_cni,
    aws_iam_role_policy_attachment.eks_nodes_ecr_ro,
  ]
}
