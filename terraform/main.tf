provider "aws" {  
  region = "us-east-1"
}

variable "bucket_name" {  
  type = string
}

variable "bucket_tag_name" {  
  description = "Tag name for the bucket"  
  type = string  
  default = "OVA Backup Bucket"
}

variable "environment" {  
  description = "Environment tag"  
  type = string  
  default = "Production"
} 

resource "aws_s3_bucket" "backup_bucket" {  
  bucket = var.bucket_name  
  tags = {    
    Name = var.bucket_tag_name    
    Environment = var.environment  
  }
}

resource "aws_s3_bucket_versioning" "backup_versioning" {
  bucket = aws_s3_bucket.backup_bucket.id  
  versioning_configuration {    
    status = "Enabled"  
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup_encryption" {  
  bucket = aws_s3_bucket.backup_bucket.id  
  rule {    
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"    
    }  
  }
}

resource "aws_s3_object" "text_file_upload" {
  bucket        = aws_s3_bucket.backup_bucket.bucket  
  key           = "backups/VM4"  
  source        = "VM4.ova"  
  etag          = filemd5("VM4.ova")  
  content_type  = "application/x-virtualbox-ova"
}

output "hello_txt_url" { 
  value = "https://${aws_s3_bucket.backup_bucket.bucket}.s3.amazonaws.com/backups/VM4"
}