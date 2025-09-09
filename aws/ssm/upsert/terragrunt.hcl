terraform {
  source = "git::https://github.com/KaribuLab/terraform-aws-parameter-upsert.git?ref=v0.5.1"
}

locals {
  serverless  = read_terragrunt_config(find_in_parent_folders("serverless.hcl"))
  base_path   = "${local.serverless.locals.parameter_path}/${local.serverless.locals.stage}/infra"
  common_tags = local.serverless.locals.common_tags
}

dependency "batch" {
  config_path = "${get_parent_terragrunt_dir()}/aws/batch"
  mock_outputs = {
    job_definition_arn = "arn:aws:batch:us-east-1:012345678901:job-definition/installer-ecr-publisher-batch-arn"
    job_queue_arn      = "arn:aws:batch:us-east-1:012345678901:job-queue/installer-ecr-publisher-job-queue-arn"
  }
}


include {
  path = find_in_parent_folders()
}

inputs = {
  base_path      = local.base_path
  binary_version = "v0.5.5"
  tags           = local.common_tags
  parameters = [
    {
      path        = "ecr-publisher-job-definition-arn"
      type        = "String"
      tier        = "Standard"
      description = "Installer ECR Publisher Job Definition ARN"
      value       = join(":", slice(split(":", dependency.batch.outputs.job_definition_arn), 0, length(split(":", dependency.batch.outputs.job_definition_arn)) - 1))
    },
    {
      path        = "ecr-publisher-job-queue-arn"
      type        = "String"
      tier        = "Standard"
      description = "Installer ECR Publisher Job Queue ARN"
      value       = dependency.batch.outputs.job_queue_arn
    }
  ]
}
