
# Allocate a public IPv4 address for the NAT Gateway.
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name    = "kafka-nat-eip"
    Project = "kafka-one-click-infra"
  }
}

# Create a NAT Gateway inside the first public subnet.
resource "aws_nat_gateway" "kafka_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id


# Route private subnet AZ A internet traffic through the NAT Gateway.
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.kafka_nat.id
}


