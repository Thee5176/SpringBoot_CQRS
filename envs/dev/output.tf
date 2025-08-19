resource "local_file" "ssh_private_key_pem" {
  content         = tls_private_key.ec2_ssh_key.private_key_pem
  filename        = "tf_generated_key.pem" # This file will be created in the current directory
  file_permission = "0600"                 # Set permissions for SSH
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance."
  value       = aws_instance.web_server.public_ip
}

output "instance_id" {
  description = "The ID of the created EC2 instance."
  value       = aws_instance.web_server.id
}