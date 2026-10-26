
# Security group for the Kafka EC2 instance.
resource "aws_security_group" "kafka_sg" {
  name        = "kafka-one-click-sg"
  description = "Security group for Kafka infrastructure"
  vpc_id      = aws_vpc.kafka_vpc.id

  # Allow Kafka traffic from within the VPC.
  ingress {
    description = "Kafka access from within the VPC"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow outbound connections for updates and downloads.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "kafka-one-click-sg"
    Project = "kafka-one-click-infra"
  }
}

# Security group for the public Application Load Balancer.
resource "aws_security_group" "alb_sg" {
  name        = "kafka-one-click-alb-sg"
  description = "Allow public HTTP traffic to the ALB"
  vpc_id      = aws_vpc.kafka_vpc.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound traffic to application instances"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "kafka-one-click-alb-sg"
    Project = "kafka-one-click-infra"
  }
}

# Security group for private application EC2 instances.tags = {
    Name    = "kafka-one-click-app-sg"
    Project = "kafka-one-click-infra"
  }
}
