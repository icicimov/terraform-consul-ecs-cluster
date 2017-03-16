/*=== ALARMS AND METRICS FOR APP CONTAINER AUTOSCALING ===*/
resource "aws_cloudwatch_metric_alarm" "nodejs-app_service_cpu_high" {
  alarm_name          = "${var.vpc["tag"]}-ecs-${var.app["name"]}-cpu-high"
  alarm_description   = "This alarm monitors ${var.app["name"]} CPU utilization for scaling up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_up.arn}"]
  dimensions {
    ClusterName = "${var.ecs["cluster_name"]}"
    ServiceName = "${var.app["name"]}"
  }
}

resource "aws_cloudwatch_metric_alarm" "nodejs-app_service_cpu_low" {
  alarm_name          = "${var.vpc["tag"]}-ecs-${var.app["name"]}-cpu-low"
  alarm_description   = "This alarm monitors ${var.app["name"]} CPU utilization for scaling down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_down.arn}"]
  dimensions {
    ClusterName = "${var.ecs["cluster_name"]}"
    ServiceName = "${var.app["name"]}"
  }
}

resource "aws_cloudwatch_metric_alarm" "nodejs-app_service_memory_high" {
  alarm_name          = "${var.vpc["tag"]}-ecs-${var.app["name"]}-memory-high"
  alarm_description   = "This alarm monitors ${var.app["name"]} memory utilization for scaling up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_up.arn}"]
  dimensions {
    ClusterName = "${var.ecs["cluster_name"]}"
    ServiceName = "${var.app["name"]}"
  }
}

resource "aws_cloudwatch_metric_alarm" "nodejs-app_service_memory_low" {
  alarm_name          = "${var.vpc["tag"]}-ecs-${var.app["name"]}-memory-low"
  alarm_description   = "This alarm monitors ${var.app["name"]} memory utilization for scaling down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"
  alarm_actions       = ["${aws_appautoscaling_policy.scale_down.arn}"]
  dimensions {
    ClusterName = "${var.ecs["cluster_name"]}"
    ServiceName = "${var.app["name"]}"
  }
}

/*== ECS APP CONTAINER AUTOSCALING ==*/
resource "aws_appautoscaling_target" "target" {
  resource_id        = "service/${var.ecs["cluster_name"]}/${var.vpc["tag"]}-ecs-${var.app["name"]}-service"
  role_arn           = "${aws_iam_role.ecs_service_autoscaling_role.arn}"
  min_capacity       = "${var.app["min_capacity"]}"
  max_capacity       = "${var.app["max_capacity"]}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "scale_up" {
  name               = "${var.vpc["tag"]}-ecs-${var.app["name"]}-scale-up"
  resource_id        = "service/${var.ecs["cluster_name"]}/${var.vpc["tag"]}-ecs-${var.app["name"]}-service"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  adjustment_type    = "ChangeInCapacity"
  cooldown           = 120
  metric_aggregation_type = "Average"
  step_adjustment {
    scaling_adjustment          = 1
    metric_interval_lower_bound = 0
  }
  depends_on = ["aws_appautoscaling_target.target"]
}

resource "aws_appautoscaling_policy" "scale_down" {
  name               = "${var.vpc["tag"]}-ecs-${var.app["name"]}-scale-down"
  resource_id        = "service/${var.ecs["cluster_name"]}/${var.vpc["tag"]}-ecs-${var.app["name"]}-service"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  adjustment_type    = "ChangeInCapacity"
  cooldown           = 120
  metric_aggregation_type = "Average"
  step_adjustment {
    scaling_adjustment         = -1
    metric_interval_upper_bound = 0
  }
  depends_on = ["aws_appautoscaling_target.target"]
}

/* NOTE: I like creating separate IAM roles and policies per VPC. However, I have created the AWS Managed 
   ecsInstanceRole and ecsAutoscaleRole in the IAM console so we can use those pre-made roles ARN instead 
   of creating a new ones as shown below. The benefit of these Managed roles is that they are maintanied 
   by AWS meaning they will receive regular updates automatically in the future as new features or services
   are being introduced.
*/
/*== ECS APP CONTAINER AUTOSCALING IAM ROLE ==*/
resource "aws_iam_role" "ecs_service_autoscaling_role" {
  name               = "${var.vpc["tag"]}-ecs-${var.app["name"]}-as-role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_service_autoscaling_role.json}"
}

data "aws_iam_policy_document" "ecs_service_autoscaling_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["application-autoscaling.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ecs_service_autoscaling_policy" {
  name   = "${var.vpc["tag"]}-ecs-${var.app["name"]}-as-policy"
  role   = "${aws_iam_role.ecs_service_autoscaling_role.id}"
  policy = "${data.aws_iam_policy_document.ecs_service_autoscaling_policy.json}"
}

data "aws_iam_policy_document" "ecs_service_autoscaling_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "cloudwatch:DescribeAlarms"
    ]
  }
}