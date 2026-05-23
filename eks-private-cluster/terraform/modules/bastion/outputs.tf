output "instance_id"        { value = aws_instance.bastion.id }
output "eic_endpoint_id"   { value = aws_ec2_instance_connect_endpoint.bastion.id }
output "security_group_id" { value = aws_security_group.bastion.id }
output "role_arn"           { value = aws_iam_role.bastion.arn }
