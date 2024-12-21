variable "environment" {
  description = "Environment (staging/production)"
  type        = string
}

variable "environments" {
  description = "Environment specific variables"
  type = map(object({
    instance_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
  }))
  default = {
    staging = {
      instance_type = "t2.large"
      min_size      = 1
      max_size      = 2
      desired_size  = 1
    }
    production = {
      instance_type = "t2.2xlarge"
      min_size      = 2
      max_size      = 4
      desired_size  = 2
    }
  }
}