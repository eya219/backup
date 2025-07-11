provider "aws" {
  region = var.region
}

variable "bucket_name" {
  type = string
}

variable "region" {
  type = string
  default = "us-east-1"
}

resource "aws_s3_bucket" "backup_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = "OVA Backup Bucket"
    Environment = "Production"
  }
}

resource "aws_s3_object" "text_file_upload" {
  bucket       = aws_s3_bucket.backup_bucket.id
  key          = "backups/VM4"
  source       = "VM4.ova"
  etag         = filemd5("VM4.ova")
  content_type = "application/x-virtualbox-ova"
}

output "ova_file_url" {
  value = "https://${aws_s3_bucket.backup_bucket.bucket}.s3.amazonaws.com/backups/VM4"
}