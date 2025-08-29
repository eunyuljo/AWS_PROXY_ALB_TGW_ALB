variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "alb-routing"
}

variable "frontend_vpc_cidr" {
  description = "CIDR block for frontend VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "backend_vpc_cidr" {
  description = "CIDR block for backend VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "domain_mappings" {
  description = "Domain to backend service mappings"
  type = map(object({
    domain = string
    port   = number
  }))
  default = {
    "service-a" = {
      domain = "service-a.example.com"
      port   = 8080
    }
    "service-b" = {
      domain = "service-b.example.com"
      port   = 8081
    }
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}