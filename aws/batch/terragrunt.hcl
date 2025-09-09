terraform {
  source = "git::https://github.com/KaribuLab/terraform-aws-batch.git?ref=v0.2.0"
}

locals {
  serverless  = read_terragrunt_config(find_in_parent_folders("serverless.hcl"))
  batch_name  = "${local.serverless.locals.service_name}-batch-${local.serverless.locals.stage}"
  common_tags = local.serverless.locals.common_tags
  base_path   = "${local.serverless.locals.parameter_path}/${local.serverless.locals.stage}"
}

include {
  path = find_in_parent_folders()
}

dependency parameters {
  config_path = "${get_parent_terragrunt_dir()}/aws/ssm/lookup"
  mock_outputs = {
    parameters = {
      "/tvo/security-scan/test/infra/vpc-id"           = "vpc-000000000000000"
      "/tvo/security-scan/test/infra/subnet1"          = "subnet-0c4b3b6b1b7b3b3b3"
      "/tvo/security-scan/test/infra/ecr-registry-url" = "vpc-000000000000000"
      "/tvo/security-scan/test/infra/ecr-registry-arn" = "arn:aws:ecr:us-east-1:123456789012:repository/titvo-installer-ecr-publisher"
      "/tvo/security-scan/prod/infra/vpc-id"           = "vpc-000000000000000"
      "/tvo/security-scan/prod/infra/subnet1"          = "subnet-0c4b3b6b1b7b3b3b3"
      "/tvo/security-scan/prod/infra/ecr-registry-url" = "123456789012.dkr.ecr.us-east-1.amazonaws.com"
      "/tvo/security-scan/prod/infra/ecr-registry-arn" = "arn:aws:ecr:us-east-1:123456789012:repository/titvo-installer-ecr-publisher"
    }
  }
}

inputs = {
  subnet_ids = [
    dependency.parameters.outputs.parameters["${local.base_path}/infra/subnet1"],
  ]
  name               = local.batch_name
  common_tags        = local.common_tags
  ecr_repository_url = "karibu/titvo-installer-ecr-publisher:latest"
  max_vcpus          = 16
  job_vcpu           = 2
  job_memory         = 4096
  vpc_id             = dependency.parameters.outputs.parameters["${local.base_path}/infra/vpc-id"]
  job_command        = "/usr/local/bin/publish.sh"
  job_privileged     = true
  job_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetAuthorizationToken"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        "Resource" : dependency.parameters.outputs.parameters["${local.base_path}/infra/ecr-registry-arn"]
      }
    ]
  })
}
