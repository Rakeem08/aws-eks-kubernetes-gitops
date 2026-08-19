data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "jenkins" {
  name_prefix = "${var.project_name}-jenkins-"
  description = "Allow Jenkins access from the administrator IP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from administrator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.jenkins_allowed_cidr]
  }

  ingress {
    description = "Jenkins web interface from administrator IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.jenkins_allowed_cidr]
  }

  egress {
    description = "Allow outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-jenkins-sg"
  }
}

data "aws_iam_policy_document" "jenkins_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.project_name}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "jenkins_aws_access" {
  statement {
    sid = "ECRLoginAndEKSDiscovery"

    actions = [
      "ecr:GetAuthorizationToken",
      "eks:DescribeCluster"
    ]

    resources = ["*"]
  }

  statement {
    sid = "ECRRepositoryAccess"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages"
    ]

    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "jenkins_aws_access" {
  name   = "${var.project_name}-jenkins-aws-access"
  role   = aws_iam_role.jenkins.id
  policy = data.aws_iam_policy_document.jenkins_aws_access.json
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.jenkins_instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name                    = var.jenkins_key_name
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf upgrade -y
    dnf install -y \
      fontconfig \
      java-21-amazon-corretto-headless \
      docker \
      git \
      wget \
      unzip \
      tar \
      gzip

    wget -O /etc/yum.repos.d/jenkins.repo \
      https://pkg.jenkins.io/rpm-stable/jenkins.repo

    dnf install -y jenkins

    systemctl daemon-reload
    systemctl enable --now docker

    usermod -aG docker jenkins

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
      -o /tmp/awscliv2.zip

    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install --update

    curl -L \
      "https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl" \
      -o /usr/local/bin/kubectl

    chmod +x /usr/local/bin/kubectl

    curl -fsSL \
      https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
      -o /tmp/get_helm.sh

    chmod 700 /tmp/get_helm.sh
    /tmp/get_helm.sh

    systemctl enable --now jenkins
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-jenkins"
  }
}