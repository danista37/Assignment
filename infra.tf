terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = var.region

}

# CREATE VPC ####
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = "true"
  enable_dns_support   = "true"

  tags = {
    Name = "example-vpc"
  }
}


#### create IG ####


resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name = "example-internet-gateway"
  }
}

#### ADD ROUTE TABLE TO IG ###


resource "aws_route" "route" {
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gateway.id}"
}

##################################

#### CREATE private   SUBNET


resource "aws_subnet" "private_subnet1" {
 # count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = false
  availability_zone       = var.availability_zones[0]

  tags = {
    Name = "private_subnet1"
  }
}


resource "aws_subnet" "private_subnet2" {
 # count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = var.availability_zones[3]

  tags = {
    Name = "private_subnet2"
  }
}



####CREATE SUBNET GROUP####


resource "aws_private_subnet_group" "private" {
  name       = "main"
  subnet_ids = ["${aws_subnet.private_subnet1.id}", "${aws_subnet.private_subnet2.id}"]

  tags = {
    Name = "private subnet group"
  }
}



######CREATE private SECURITY GROUP

resource "aws_security_group" "private" {
  name        = "allow"
  description = "ssh allow to the ec2"
  vpc_id      = "${aws_vpc.vpc.id}"


  ingress {
    description = "ssh"
    security_groups= ["${aws_security_group.web_sg1.id}", "${aws_security_group.web_sg2.id}"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
 

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG OF private"
  }
}

### CREATE S3 Role Access
resource "aws_s3_bucket" "some-bucket" {
  bucket = "my-bucket-name"
}

resource "aws_s3_bucket" "some_bucket" {
  bucket = "my-bucket-name"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "some_bucket_access" {
  bucket = aws_s3_bucket.some_bucket.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
}

resource "aws_iam_policy" "bucket_policy" {
  name        = "my-bucket-policy"
  path        = "/"
  description = "Allow "

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::my-bucket-name"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "some_role" {
  name = "my_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "some_bucket_policy" {
  role       = aws_iam_role.some_role.name
  policy_arn = aws_iam_policy.bucket_policy.arn
}

resource "aws_iam_role_policy_attachment" "cloud_watch_policy" {
  role       = aws_iam_role.some_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "some_profile" {
  name = "some-profile"
  role = aws_iam_role.some_role.name
}






########### START OF Ec2 SECTION #########


#### CREATE  WEB SUBNET####### 

resource "aws_subnet" "web_subnet2" {
 # count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zones[1]

  tags = {
    Name = "public-subnet2"
  }
}


resource "aws_subnet" "web_subnet3" {
 # count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zones[2]

  tags = {
    Name = "public-subnet3"
  }
}






#CREATE  WEB SUCURITY GROUP
resource "aws_security_group" "web_sg1" {
  name   = "SG for Instance"
  description = "Terraform example security group"
  vpc_id      = "${aws_vpc.vpc.id}"  
   ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 22 
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
    Name = "WEB-security-group1"
  }
}


#CREATE WEB SUCURITY GROUP2
resource "aws_security_group" "web_sg2" {
  name   = "SG2 for Instance"
  description = "Terraform example security group"
  vpc_id      = "${aws_vpc.vpc.id}"
   ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 0
    to_port     = 22 
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
    Name = "WEB-security-group2"
  }
}


####CREATE EC2 INSTANCE
resource "aws_instance" "app_server" {
  ami                                  = var.amis[var.region]
#   ami                                  = "ami-0dc2d3e4c0f9ebd18"
  instance_type                        = "t2.micro"
#   instance_type                        = "var.instance_type"
  iam_instance_profile = aws_iam_instance_profile.some_profile.id
  associate_public_ip_address          = true
  key_name                             = "test"
#  availability_zone                    = var.availability_zone
  vpc_security_group_ids               = ["${aws_security_group.web_sg1.id}", "${aws_security_group.web_sg2.id}"]
  subnet_id                            = "${aws_subnet.web_subnet2.id}" 
  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing apache2"
  sudo apt update -y
  sudo apt install apache2 -y
  echo "*** Completed Installing apache2"
  EOF
  instance_initiated_shutdown_behavior = "terminate"
  root_block_device {
    volume_type = "gp3"
    volume_size = "15"
  }


  tags = {
    Name = var.instance_name
  }
 

}






#################  ###################
###### CREATE EC2 IMAGE #########


resource "aws_ami_from_instance" "ec2_image" {
  name               = "terraform-example"
  source_instance_id = "${aws_instance.app_server.id}"

depends_on = [aws_instance.app_server]
}


####### CREATE AUTO SCALING LAUNCH COINFIG #######




resource "aws_launch_configuration" "ec2" {
  image_id               = "${aws_ami_from_instance.ec2_image.id}"
  instance_type          = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.some_profile.id
  key_name               = "test"
  security_groups        =  ["${aws_security_group.web_sg1.id}", "${aws_security_group.web_sg2.id}"]
  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing apache2"
  sudo apt update -y
  sudo apt install apache2 -y
  echo "*** Completed Installing apache2"
  EOF

  lifecycle {
    create_before_destroy = true
  }
}


## Creating AutoScaling Group
resource "aws_autoscaling_group" "ec2" {
  launch_configuration = "${aws_launch_configuration.ec2.id}"
#  availability_zones = var.availability_zones
  min_size = 1
  max_size = 3
#   load_balancers = ["${aws_alb.alb.id}"]

  target_group_arns = ["${aws_alb_target_group.group.arn}"]
 vpc_zone_identifier  = ["${aws_subnet.web_subnet3.id}", "${aws_subnet.web_subnet2.id}"]
  health_check_type = "EC2"
}


resource "aws_autoscaling_policy" "web_policy_down" {
  name = "web_policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_launch_configuration.ec2.id
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "60"

  dimensions = {
    AutoScalingGroupName = aws_launch_configuration.ec2.id
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.web_policy_down.arn ]
}
resource "aws_autoscaling_policy" "web_policy_up" {
  name = "web_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name =  aws_launch_configuration.ec2.id
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "80"

  dimensions = {
   autoscaling_group_name =  aws_launch_configuration.ec2.id
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.web_policy_up.arn ]
}


#####Create an application load balancer SG

resource "aws_security_group" "alb" {
  name        = "terraform_alb_security_group"
  description = "Terraform load balancer security group"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = "${var.allowed_cidr_blocks}"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = "${var.allowed_cidr_blocks}"
  }
 # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags =  {
    Name = "alb-security-group"
  }
}

resource "aws_alb" "alb" {
  name            = "terraform-example-alb"
  security_groups = ["${aws_security_group.alb.id}"]
  subnets         = ["${aws_subnet.web_subnet2.id}","${aws_subnet.web_subnet3.id}"]
#   subnets         = aws_subnet.main.*.id
  tags = {
    Name = "example-alb"
  }
}



##### create new target group

resource "aws_alb_target_group" "group" {
  name     = "terraform-example-alb-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc.id}"
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/login"
    port = 80
  }
}

##### lb listerners


resource "aws_alb_listener" "listener_http" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.group.arn}"
    type             = "forward"
  }
}


output "ip" {
  value = "${aws_instance.app_server.public_ip}"
}

output "lb_address" {
  value = "${aws_alb.alb.dns_name}"
}
