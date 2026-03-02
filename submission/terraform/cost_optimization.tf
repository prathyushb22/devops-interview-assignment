# cost_optimization.tf — Cost Optimization Resources
#
# TASK: Review data/aws_cost_report.json and implement cost-saving measures.
#
# Requirements:
#   1. Analyze the cost report and identify the top savings opportunities
#   2. Implement Terraform resources that address the findings, such as:
#      - S3 lifecycle policies for tiered storage
#      - Spot/mixed instance configurations for node groups
#      - Right-sizing recommendations implemented as resource changes
#   3. Add a comment block at the top explaining your cost analysis:
#      - Current monthly cost and top cost drivers
#      - Proposed changes and estimated savings
#      - Any trade-offs or risks

# --- Cost analysis ---

# Report period: 2025-11-01 .. 2025-11-30
# Current monthly cost: $47,832.15
#
# Top cost drivers:
#   - EC2 (mostly EKS worker nodes): $22,145.60
#       * video-processing: 8x c5.4xlarge (avg util 34%), $11,520 (on-demand)
#       * general: 6x m5.2xlarge (avg util 22%), $5,544 (on-demand)
#       * gpu-inference: 4x g4dn.xlarge (avg util 61%), $3,168 (on-demand)
#       * bastion hosts: 3x t3.medium (avg util 5%), $793.60
#   - S3: $12,340.50
#       * vlt-video-chunks-prod: 45 TB STANDARD, $10,350; 95% of access within 30 days; oldest objects ~730 days
#       * vlt-logs-prod: 8.2 TB STANDARD, $1,415.50; rarely accessed after 7 days
#
# Proposed changes implemented:
#   1) S3 lifecycle tiering for video chunks + logs:
#      - video chunks: STANDARD_IA @30d, GLACIER_IR @90d, DEEP_ARCHIVE @180d, expire @730d
#      - logs: STANDARD_IA @7d, GLACIER_IR @30d, expire @545d
#      Estimated savings: material reduction for 45 TB STANDARD moved to colder tiers after 30 days.
#
#   2) Spot + right-sizing for underutilized CPU node groups:
#      - general: move from m5.2xlarge on-demand to SPOT mixed instances (m5/m6i large/xlarge) and reduce baseline size
#      - video-processing: move from c5.4xlarge on-demand to SPOT mixed instances (c5/c6i 2xlarge/4xlarge) and reduce baseline size
#      Estimated savings: large (Spot often ~60–90% cheaper) but depends on interruption rates and instance availability.
#
# Trade-offs / risks:
#   - S3 lifecycle: older-object reads incur higher retrieval cost + latency; applications must tolerate this.
#   - Spot: workloads must be interruption-tolerant; use PDBs, HPA, graceful shutdown; avoid stateful/latency-critical-only-on-spot.
#   - Right-sizing: smaller instances may require scaling adjustments; monitor CPU/memory and pod density.


# --- S3 Lifecycle Policies ---
resource "aws_s3_bucket" "video_chunks" {
  bucket        = var.video_chunks_bucket
  force_destroy = false

  tags = {
    Name        = var.video_chunks_bucket
    Environment = var.environment
    Site        = var.site_id
  }
}

resource "aws_s3_bucket_public_access_block" "video_chunks" {
  bucket                  = aws_s3_bucket.video_chunks.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "video_chunks" {
  bucket = aws_s3_bucket.video_chunks.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "video_chunks" {
  bucket = aws_s3_bucket.video_chunks.id

  rule {
    id     = "tier-video-chunks"
    status = "Enabled"
    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 730
    }
  }
}

# --- Spot/Mixed Instance Configuration ---
resource "aws_eks_node_group" "general_cost_optimized" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${var.environment}-general"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  capacity_type  = "SPOT"
  instance_types = ["m6i.large", "m5.large", "m6i.xlarge", "m5.xlarge"]

  scaling_config {
    min_size     = var.general_node_min
    desired_size = var.general_node_desired
    max_size     = var.general_node_max
  }

  labels = {
    workload = "general"
    cost     = "spot"
  }

  update_config {
    max_unavailable = 1
  }
}

resource "aws_eks_node_group" "video_processing_cost_optimized" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${var.environment}-video-processing"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  capacity_type  = "SPOT"
  instance_types = ["c6i.2xlarge", "c5.2xlarge", "c6i.4xlarge", "c5.4xlarge"]

  scaling_config {
    min_size     = var.video_processing_min
    desired_size = var.video_processing_desired
    max_size     = var.video_processing_max
  }

  labels = {
    workload = "video-processing"
    cost     = "spot"
  }

  update_config {
    max_unavailable = 1
  }
}

# --- Other Cost Optimizations ---
resource "aws_s3_bucket" "logs" {
  bucket        = var.logs_bucket
  force_destroy = false

  tags = {
    Name        = var.logs_bucket
    Environment = var.environment
    Site        = var.site_id
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "tier-logs"
    status = "Enabled"
    filter {}

    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 30
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 545
    }
  }
}

