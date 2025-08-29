# Frontend ALB Security Group
resource "aws_security_group" "frontend_alb" {
  name        = "${var.project_name}-frontend-alb-sg"
  description = "Security group for frontend ALB"
  vpc_id      = aws_vpc.frontend.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-frontend-alb-sg"
  }
}

# Frontend ALB
resource "aws_lb" "frontend" {
  name               = "${var.project_name}-frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_alb.id]
  subnets            = aws_subnet.frontend_public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-frontend-alb"
  }
}

# Target Groups pointing to backend EC2 instances via TGW
resource "aws_lb_target_group" "backend_services" {
  for_each = var.domain_mappings

  name        = "${substr(var.project_name, 0, 10)}-${each.key}-tg"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.frontend.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    protocol            = "HTTP"
    port                = "traffic-port"
  }

  tags = {
    Name = "${var.project_name}-${each.key}-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "No matching host found"
      status_code  = "404"
    }
  }

  tags = {
    Name = "${var.project_name}-frontend-listener"
  }
}

# Listener Rules for host-based routing
resource "aws_lb_listener_rule" "host_based_routing" {
  for_each = var.domain_mappings

  listener_arn = aws_lb_listener.frontend.arn
  priority     = 100 + index(keys(var.domain_mappings), each.key)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_services[each.key].arn
  }

  condition {
    host_header {
      values = [each.value.domain]
    }
  }

  tags = {
    Name = "${var.project_name}-${each.key}-rule"
  }
}