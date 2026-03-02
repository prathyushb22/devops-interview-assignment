output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = "aws_eks_cluster.main.endpoint"
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway — add this to allowlists on external services (ECR, S3 VPC endpoint fallback) that restrict by source IP"
  value       = aws_eip.nat.public_ip
}

# TODO: Add outputs for:
# - Private subnet IDs
# - Public subnet IDs
# - NAT Gateway IPs
# - S3 bucket names
# - Any other values downstream consumers need
