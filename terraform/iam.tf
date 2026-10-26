
# Define the trust policy that allows EC2 to assume this role.
data "aws_iam_policy_document" "ec2_assume_role" {
  

# Create an IAM role for the Kafka EC2 instance.
resource "aws_iam_role" "kafka_ec2_role" {
  name               = "kafka-one-click-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Project = "kafka-one-click-infra"
  }
}

# Allow the EC2 instance to communicate with AWS Systems Manager.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.kafka_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create an instance profile to attach the role to EC2.
resource "aws_iam_instance_profile" "kafka_ec2_profile" {
  name = "kafka-one-click-instance-profile"
  role = aws_iam_role.kafka_ec2_role.name
}
