
# Create a private S3 bucket for Ansible SSM file transfers.
resource "aws_s3_bucket" "ssm_transfer" {
  bucket = "kafka-one-click-ssm-506192652789"

  tags = {
    Name    = "kafka-one-click-ssm-transfer"
    Project = "kafka-one-click-infra"
  }
}

# Block all public access to the SSM transfer bucket.
resource "aws_s3_bucket_public_access_block" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id

  block_public_acls       = true
  block_public_policy     = true

}

# Prevent accidental public ACLs on uploaded objects.
resource "aws_s3_bucket_ownership_controls" "ssm_transfer" {
  bucket = aws_s3_bucket.ssm_transfer.id
