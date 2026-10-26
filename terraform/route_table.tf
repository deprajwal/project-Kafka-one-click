
# Public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.kafka_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kafka_igw.id
  }

  tags = {
    Name = "kafka-public-route-table"
  }
}

# Private route table for AZ A
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.kafka_vpc.id

  tags = {
    Name = "kafka-private-route-table"
  }
}

# Private route table for AZ B
resource "aws_route_table" "private_route_table_2" {
  vpc_id = aws_vpc.kafka_vpc.id

  tags = {
    Name = "kafka-private-route-table-2"
  }
}

# Public subnet AZ A association
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private subnet AZ A association
resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

