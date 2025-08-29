# Backend Network Load Balancer for better cross-VPC routing
# Architecture: Frontend ALB -> Transit Gateway -> Backend NLB -> Backend EC2

# Backend Network Load Balancer
resource "aws_lb" "backend_nlb" {
  name               = "${var.project_name}-backend-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.backend_private[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-backend-nlb"
  }
}

# NLB Target Groups for each service
resource "aws_lb_target_group" "nlb_backend_services" {
  for_each = var.domain_mappings

  name     = "${substr(var.project_name, 0, 10)}-nlb-${each.key}"
  port     = each.value.port
  protocol = "TCP"
  vpc_id   = aws_vpc.backend.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
  }

  tags = {
    Name = "${var.project_name}-nlb-${each.key}-tg"
  }
}

# NLB Listeners for each service
resource "aws_lb_listener" "nlb_backend_services" {
  for_each = var.domain_mappings

  load_balancer_arn = aws_lb.backend_nlb.arn
  port              = each.value.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_backend_services[each.key].arn
  }

  tags = {
    Name = "${var.project_name}-nlb-${each.key}-listener"
  }
}

# Attach EC2 instances to NLB target groups
resource "aws_lb_target_group_attachment" "nlb_backend_ec2" {
  for_each = {
    for idx, instance in flatten([
      [for i in range(2) : {
        service = "service-a"
        instance_id = aws_instance.service_a[i].id
        port = var.domain_mappings["service-a"].port
        key = "service-a-${i}"
      }],
      [for i in range(2) : {
        service = "service-b"
        instance_id = aws_instance.service_b[i].id
        port = var.domain_mappings["service-b"].port
        key = "service-b-${i}"
      }]
    ]) : instance.key => instance
  }

  target_group_arn = aws_lb_target_group.nlb_backend_services[each.value.service].arn
  target_id        = each.value.instance_id
  port             = each.value.port
}

# Get NLB network interfaces to extract IP addresses
data "aws_network_interfaces" "nlb_ips" {
  depends_on = [aws_lb.backend_nlb]
  
  filter {
    name   = "description"
    values = ["ELB net/alb-routing-backend-nlb/*"]
  }
}

# Get individual network interface details
data "aws_network_interface" "nlb_interface" {
  for_each = toset(data.aws_network_interfaces.nlb_ips.ids)
  id       = each.key
}

# Register NLB IPs to Frontend ALB target groups
resource "aws_lb_target_group_attachment" "frontend_to_nlb" {
  for_each = {
    for pair in flatten([
      for service_key, service_config in var.domain_mappings : [
        for ni_id in data.aws_network_interfaces.nlb_ips.ids : {
          service = service_key
          ip = data.aws_network_interface.nlb_interface[ni_id].private_ip
          port = service_config.port
          key = "${service_key}-${substr(ni_id, -8, 8)}"
        }
      ]
    ]) : pair.key => pair
  }

  target_group_arn = aws_lb_target_group.backend_services[each.value.service].arn
  target_id        = each.value.ip
  port             = each.value.port
  availability_zone = "all"

  depends_on = [
    aws_lb.backend_nlb,
    data.aws_network_interfaces.nlb_ips
  ]
}