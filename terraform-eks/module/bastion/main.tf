terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.20.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Random string for unique names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Security Group for Bastion
resource "aws_security_group" "bastion" {
  name_prefix = "bastion-sg"
  vpc_id      = var.vpc_id

  # Allow HTTPS for SSM Agent
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS for SSM Agent"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "bastion-sg"
    }
  )
}

# IAM Role for Bastion
resource "aws_iam_role" "bastion" {
  name = "bastion-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for EKS access
resource "aws_iam_role_policy" "bastion" {
  name = "bastion-policy-${random_string.suffix.result}"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:ListUpdates",
          "eks:ListFargateProfiles",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:ListAddons",
          "eks:DescribeAddon",
          "eks:GetToken",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for Session Manager
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Additional SSM policies
resource "aws_iam_role_policy_attachment" "ssm_directory_policy" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "bastion" {
  name = "bastion-profile-${random_string.suffix.result}"
  role = aws_iam_role.bastion.name
}

# User data script to install kubectl and docker
data "template_file" "user_data" {
  template = <<-EOF
              #!/bin/bash
              # Install SSM Agent
              apt-get update
              apt-get install -y snapd
              systemctl enable snapd
              systemctl start snapd
              sleep 10
              snap install amazon-ssm-agent --classic
              systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
              systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
              
              # Verify SSM Agent status
              systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service

              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              mv kubectl /usr/local/bin/

              # Install Docker
              apt-get update
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io

              # Install AWS CLI
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              apt-get install -y unzip
              unzip awscliv2.zip
              ./aws/install

              # Create .kube directory and set permissions
              mkdir -p /home/ubuntu/.kube
              chown -R ubuntu:ubuntu /home/ubuntu/.kube
              chmod 700 /home/ubuntu/.kube

              # Configure kubectl for EKS
              aws eks update-kubeconfig --name example-eks-cluster-01yscdhc --region us-east-1

              # Move kubeconfig to user's home directory
              mv /root/.kube/config /home/ubuntu/.kube/
              chown ubuntu:ubuntu /home/ubuntu/.kube/config
              chmod 600 /home/ubuntu/.kube/config

              # Add kubectl completion
              echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
              echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
              echo 'complete -F __start_kubectl k' >> /home/ubuntu/.bashrc

              # Add AWS CLI completion
              echo 'complete -C /usr/local/bin/aws_completer aws' >> /home/ubuntu/.bashrc

              # Set environment variables
              echo 'export AWS_DEFAULT_REGION=us-east-1' >> /home/ubuntu/.bashrc
              echo 'export KUBECONFIG=/home/ubuntu/.kube/config' >> /home/ubuntu/.bashrc

              # Install additional useful tools
              apt-get install -y jq gettext-base

              # Create a test script to verify cluster access
              cat > /home/ubuntu/test-cluster.sh << 'EOT'
              #!/bin/bash
              echo "Testing cluster access..."
              kubectl get nodes
              kubectl get pods -A
              EOT

              chmod +x /home/ubuntu/test-cluster.sh
              chown ubuntu:ubuntu /home/ubuntu/test-cluster.sh

              # Create a script to update kubeconfig
              cat > /home/ubuntu/update-kubeconfig.sh << 'EOT'
              #!/bin/bash
              aws eks update-kubeconfig --name example-eks-cluster-01yscdhc --region us-east-1
              mv /root/.kube/config /home/ubuntu/.kube/
              chown ubuntu:ubuntu /home/ubuntu/.kube/config
              chmod 600 /home/ubuntu/.kube/config
              echo "Kubeconfig updated successfully!"
              EOT

              chmod +x /home/ubuntu/update-kubeconfig.sh
              chown ubuntu:ubuntu /home/ubuntu/update-kubeconfig.sh
              EOF
}

# EC2 Instance
resource "aws_instance" "bastion" {
  ami                    = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  user_data              = data.template_file.user_data.rendered
  associate_public_ip_address = true  # Asegurar que tenga IP pública

  tags = merge(
    var.tags,
    {
      Name = "bastion-host"
    }
  )
} 