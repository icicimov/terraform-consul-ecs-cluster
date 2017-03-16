/*=== ECS CLUSTER ===*/
resource "aws_ecs_cluster" "example_cluster" {
  name = "${var.ecs["cluster_name"]}"
}

/*== ECS CLUSTER SECURITY GROUP ==*/
resource "aws_security_group" "ecs_instance" {
  name        = "${var.vpc["tag"]}-ecs-sg"
  description = "Security group for the EC2 instances in the ECS cluster"
  vpc_id      = "${var.vpc["id"]}"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = "${var.app["listen_port_http"]}"
    to_port     = "${var.app["listen_port_http"]}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8400
    to_port     = 8400
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc["cidr_block"]}"]
  }
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc["cidr_block"]}"]
  }
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc["cidr_block"]}"]
  }
  ingress {
    from_port   = "8301"
    to_port     = "8302"
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc["cidr_block"]}"]
  }
  ingress {
    from_port   = "8301"
    to_port     = "8302"
    protocol    = "udp"
    cidr_blocks = ["${var.vpc["cidr_block"]}"]
  }
  ingress {
    from_port   = "53"
    to_port     = "53"
    protocol    = "udp"
    cidr_blocks = ["${var.vpc["cidr_block"]}"]
  }
  ingress {
    protocol  = "tcp"
    from_port = 8080
    to_port   = 8080
    security_groups = [
      "${aws_security_group.nodejs-app.id}",
    ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
}

/*== ECS CLUSTER INSTANCES ASG ==*/
resource "aws_autoscaling_group" "ecs_cluster_instances" {
    name                      = "${var.vpc["tag"]}-ecs-asg"
    availability_zones        = "${split(",", lookup(var.azs, var.provider["region"]))}"
    vpc_zone_identifier       = "${split(",", lookup(var.vpc_subnets, var.vpc["id"]))}"
    max_size                  = 3
    min_size                  = 2
    health_check_grace_period = 60
    default_cooldown          = 300
    health_check_type         = "EC2"
    desired_capacity          = 2
    force_delete              = true
    launch_configuration      = "${aws_launch_configuration.ecs_instance.name}"
    termination_policies      = "${split(",", var.ecs["termination_policies"])}"
    tag {
      key                 = "Name"
      value               = "ECS-${var.vpc["tag"]}"
      propagate_at_launch = true
    }
    tag {
      key                 = "Environment"
      value               = "${lower(var.vpc["tag"])}"
      propagate_at_launch = true
    }
    tag {
      key                 = "Type"
      value               = "ecs"
      propagate_at_launch = true
    }
    tag {
      key                 = "Role"
      value               = "host"
      propagate_at_launch = true
    }
    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_launch_configuration" "ecs_instance" {
    name_prefix          = "${var.vpc["tag"]}-ecs-lc-"
    image_id             = "${data.aws_ami.ecs.id}"
    instance_type        = "${var.ecs["instance_type"]}"
    iam_instance_profile = "${aws_iam_instance_profile.ecs_instance.name}"
    key_name             = "${var.key_name}"
    security_groups      = ["${aws_security_group.ecs_instance.id}"]
    user_data            = "${data.template_file.ecs_instance.rendered}"
    lifecycle {
      create_before_destroy = true
    }
}

data "template_file" "ecs_instance" {
    template = "${file("${var.ecs["file_name"]}")}"
    vars {
        ECS_NAME       = "${var.ecs["cluster_name"]}"
        DNS_IP         = "${cidrhost(var.vpc["cidr_block"], 2)}"
        CONSUL_DC      = "${var.consul["data_center"]}"
        CONSUL_KEY     = "${var.consul["encrypt_key"]}"
        CONSUL_USER    = "${var.consul["cert_download_user"]}"
        CONSUL_SERVERS = "${var.consul["servers"]}"
    }
}

/*== POLICIES AND METRIC ALARMS FOR ASG ACTIONS ==*/
resource "aws_autoscaling_policy" "ecs_cluster_instances_up" {
  name                   = "${var.vpc["tag"]}-ecs-cluster-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.ecs_cluster_instances.name}"
}

resource "aws_autoscaling_policy" "ecs_cluster_instances_down" {
  name                   = "${var.vpc["tag"]}-ecs-cluster-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.ecs_cluster_instances.name}"
}

resource "aws_cloudwatch_metric_alarm" "ecs_cluster_cpu_high" {
  alarm_name          = "${var.vpc["tag"]}-ecs-cluster-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"
  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.ecs_cluster_instances.name}"
  }
  alarm_description = "This metric monitors ecs cluster high cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.ecs_cluster_instances_up.arn}"]
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "ecs_cluster_cpu_low" {
  alarm_name          = "${var.vpc["tag"]}-ecs-cluster-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.ecs_cluster_instances.name}"
  }
  alarm_description = "This metric monitors ec2 low cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.ecs_cluster_instances_down.arn}"]
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "ecs_cluster_memory_high" {
  alarm_name          = "${var.vpc["tag"]}-ecs-cluster-memory-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "90"
  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.ecs_cluster_instances.name}"
  }
  alarm_description = "This metric monitors ecs cluster high memory utilization"
  alarm_actions     = ["${aws_autoscaling_policy.ecs_cluster_instances_up.arn}"]
  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "ecs_cluster_memory_low" {
  alarm_name          = "${var.vpc["tag"]}-ecs-cluster-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "10"
  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.ecs_cluster_instances.name}"
  }
  alarm_description = "This metric monitors ecs cluster low memory utilization"
  alarm_actions     = ["${aws_autoscaling_policy.ecs_cluster_instances_down.arn}"]
  insufficient_data_actions = []
}

/*== AUTOSCALING NOTIFICATIONS ==*/
resource "aws_autoscaling_notification" "ecs_cluster_instances" {
  group_names = [
    "${aws_autoscaling_group.ecs_cluster_instances.name}"
  ]
  notifications  = [
    "autoscaling:EC2_INSTANCE_LAUNCH", 
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
  ]
  topic_arn = "${aws_sns_topic.ecs_cluster_instances.arn}"
}

resource "aws_sns_topic" "ecs_cluster_instances" {
  name = "${lower(var.vpc["tag"])}-ecs-sns-topic"
  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint ${var.vpc["sns_email"]}"
  }
}

/* NOTE: I like creating separate IAM roles and policies per VPC. However, I have created the AWS Managed 
   ecsInstanceRole and ecsAutoscaleRole in the IAM console so we can use those pre-made roles ARN instead 
   of creating a new ones as shown below. The benefit of these Managed roles is that they are maintanied 
   by AWS meaning they will receive regular updates automatically in the future as new features or services
   are being introduced.
*/
/*== ECS CLUSTER INSTANCES IAM ==*/
resource "aws_iam_instance_profile" "ecs_instance" {
    name  = "${var.vpc["tag"]}-ecs-profile"
    roles = ["${aws_iam_role.ecs_instance.name}"]
    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_iam_role" "ecs_instance" {
    name               = "${var.vpc["tag"]}-ecs-role"
    path               = "/"
    assume_role_policy = "${data.aws_iam_policy_document.ecs_instance.json}"
    lifecycle {
      create_before_destroy = true
    }
}

data "aws_iam_policy_document" "ecs_instance" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ecs_cluster_agent" {
  name   = "${var.vpc["tag"]}-ecs-role-policy"
  role   = "${aws_iam_role.ecs_instance.id}"
  policy = "${data.aws_iam_policy_document.ecs_cluster_agent.json}"
}

data "aws_iam_policy_document" "ecs_cluster_agent" {
  statement {
    sid       = "ECSClusterInstanceRole"
    effect    = "Allow"
    resources = ["*"]
    actions   = [
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:Submit*",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
  }
  statement {
    sid       = "allowLoggingToCloudWatch"
    effect    = "Allow"
    resources = [
      "${aws_cloudwatch_log_group.app.arn}",
      "${aws_cloudwatch_log_group.ecs.arn}"
    ]
    actions   = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }
}

/*== ECS CLUSTER SERVICES IAM ==*/
resource "aws_iam_role" "ecs_service_role" {
  name               = "${var.vpc["tag"]}-ecs-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_role.json}"
}

data "aws_iam_policy_document" "ecs_service_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

/*= IAM Policy that allows ECS Service EC2 Instance communication =*/
resource "aws_iam_role_policy" "ecs_service_policy" {
  name   = "${var.vpc["tag"]}-ecs-service-policy"
  role   = "${aws_iam_role.ecs_service_role.id}"
  policy = "${data.aws_iam_policy_document.ecs_service_policy.json}"
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:RegisterTargets",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress"
    ]
  }
}