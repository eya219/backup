provider "aws" {
  region = var.region
}

resource "aws_iam_role" "vmimport" {
  name = "vmimport"
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [{
      "Effect" = "Allow",
      "Principal" = {
        "Service" = "vmie.amazonaws.com"
      },
      "Action" = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vmimport_policy" {
  name = "vmimport-policy"
  role = aws_iam_role.vmimport.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket"],
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}",
          "arn:aws:s3:::${var.s3_bucket}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:ImportImage",
          "ec2:ImportSnapshot",
          "ec2:DescribeImportImageTasks",
          "ec2:DescribeImportSnapshotTasks",
          "ec2:CancelImportTask",
          "ec2:RegisterImage",
          "ec2:DescribeImages",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags",
          "ec2:DeleteSnapshot",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateKeyPair",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways"
        ],
        Resource = "*"
      }
    ]
  })
}
