
# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "kafka-one-click-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [
    aws_subnet.public_subnet.id,
    aws_subnet.public_subnet_2.id
  ]

  tags = {
    Name    = "kafka-one-click-alb"
    Project = "kafka-one-click-infra"
  }
}
  tags = {
    Name    = "kafka-one-click-app-tg"
    Project = "kafka-one-click-infra"
  }


# Launch template for application EC2 instances
resource "aws_launch_template" "app_template" {
  name_prefix   = "kafka-one-click-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.app_instance_type

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  update_default_version = true

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf install -y nginx

    cat > /usr/share/nginx/html/index.html <<'HTML'
    <!doctype html>
    <html>
      <head><title>Kafka One-Click Infrastructure</title></head>
      <body>
        <h1>Kafka One-Click Infrastructure</h1>
        <p>Application server is running.</p>
        <p>Served by an Auto Scaling Group instance.</p>
      </body>
    </html>
    HTML

    cat > /etc/nginx/default.d/health.conf <<'NGINX'
    location = /health {
        access_log off;
        default_type text/plain;
        return 200 'healthy';
    }
    NGINX

    systemctl enable --now nginx
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "kafka-one-click-app"
      Project = "kafka-one-click-infra"
      Tier    = "Application"
    }
  }

  tags = {
    Name    = "kafka-one-click-app-template"
    Project = "kafka-one-click-infra"
  }
}

# Auto Scaling Group for application instances
resource "aws_autoscaling_group" "app_asg" {
  name             = "kafka-one-click-app-asg"
  min_size         = var.asg_min_size
  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size
  vpc_zone_identifier = [
    aws_subnet.private_subnet.id,
    aws_subnet.private_subnet_2.id
  ]

  target_group_arns         = [aws_lb_target_group.app_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Project"
    value               = "kafka-one-click-infra"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "kafka-one-click-app"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.app_listener]
}


# ALB DNS name output
output "app_alb_dns_name" {
  description = "Public DNS name of the application load balancer"
  value       = aws_lb.app_alb.dns_name
}

output "app_alb_url" {
  description = "HTTP URL of the application load balancer"
  value       = "http://${aws_lb.app_alb.dns_name}"
}

# Application Auto Scaling Group output
output "app_asg_name" {
  description = "Name of the application Auto Scaling Group"
  value       = aws_autoscaling_group.app_asg.name
}
