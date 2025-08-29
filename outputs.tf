output "frontend_alb_dns" {
  description = "DNS name of the frontend ALB"
  value       = aws_lb.frontend.dns_name
}

# Backend ALB/NLB removed - using direct EC2 targeting through TGW

output "test_urls" {
  description = "Test URLs for domain-based routing"
  value = {
    for key, mapping in var.domain_mappings : key => {
      curl_command = "curl -H 'Host: ${mapping.domain}' http://${aws_lb.frontend.dns_name}/"
      domain       = mapping.domain
      port         = mapping.port
    }
  }
}

output "ssm_connect_commands" {
  description = "Commands to connect to EC2 instances via SSM"
  value = {
    service_a_instances = [
      for i, instance in aws_instance.service_a : {
        instance_id = instance.id
        command     = "aws ssm start-session --target ${instance.id}"
      }
    ]
    service_b_instances = [
      for i, instance in aws_instance.service_b : {
        instance_id = instance.id
        command     = "aws ssm start-session --target ${instance.id}"
      }
    ]
  }
}

output "tgw_id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.main.id
}

output "vpc_ids" {
  description = "VPC IDs"
  value = {
    frontend = aws_vpc.frontend.id
    backend  = aws_vpc.backend.id
  }
}