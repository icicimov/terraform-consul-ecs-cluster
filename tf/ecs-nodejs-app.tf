/*=== ECS TASKS AND SERVICES ===*/
resource "aws_ecs_task_definition" "nodejs-app" {
  family                = "nodejs-app"
  container_definitions = "${data.template_file.task_definition.rendered}"
}

data "template_file" "task_definition" {
  template = "${file("${var.app["file_name"]}")}"
  vars {
    image_url        = "${var.app["image"]}:${var.app["version"]}"
    container_name   = "${var.app["name"]}"
    container_cpu    = "${var.app["cpu"]}"
    container_memory = "${var.app["memory"]}"
    container_port   = "${var.app["listen_port_http"]}"
    log_group_region = "${var.provider["region"]}"
    log_group_name   = "${aws_cloudwatch_log_group.app.name}"
    enc_env          = "${var.vpc["tag"]}"
  }
}

resource "aws_ecs_service" "nodejs-app" {
  name            = "${var.vpc["tag"]}-ecs-nodejs-app-service"
  cluster         = "${aws_ecs_cluster.example_cluster.id}"
  task_definition = "${aws_ecs_task_definition.nodejs-app.arn}"
  desired_count   = 2
  deployment_minimum_healthy_percent = 50
  iam_role        = "${aws_iam_role.ecs_service_role.arn}"
  load_balancer {
    target_group_arn = "${aws_alb_target_group.nodejs-app.id}"
    container_name   = "${var.app["name"]}"
    container_port   = "${var.app["listen_port_http"]}"
  }
  depends_on = [
    "aws_iam_role_policy.ecs_service_policy",
    "aws_alb_listener.nodejs-app"
  ]
}

/*== ALB FOR THE CONTAINER APP ==*/
resource "aws_security_group" "nodejs-app" {
  name        = "${var.vpc["tag"]}-ecs-nodejs-app-alb-sg"
  description = "Security group for access to the application ELB"
  vpc_id      = "${var.vpc["id"]}"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc["cidr_block"]}"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb_target_group" "nodejs-app" {
  name     = "${var.vpc["tag"]}-ecs-nodejs-app-tg"
  port     = "${var.app["listen_port_http"]}"
  protocol = "HTTP"
  vpc_id   = "${var.vpc["id"]}"
  health_check {
    path                = "${var.app["elb_hc_uri"]}"
    port                = "${var.app["listen_port_http"]}"
    matcher             = "200"
    timeout             = 5
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags {
    "Name"        = "ALB-${var.vpc["tag"]}-${var.app["name"]}-target-group"
    "Environment" = "${lower(var.vpc["tag"])}"
  }
}

resource "aws_alb" "nodejs-app" {
  name            = "${var.vpc["tag"]}-ecs-nodejs-app-alb"
  subnets         = "${split(",", lookup(var.vpc_subnets, var.vpc["id"]))}"
  security_groups = ["${aws_security_group.nodejs-app.id}"]
  internal        = true
  tags {
    "Name"        = "ALB-${var.vpc["tag"]}-${var.app["name"]}"
    "Environment" = "${lower(var.vpc["tag"])}"
  }
}

resource "aws_alb_listener" "nodejs-app" {
  load_balancer_arn = "${aws_alb.nodejs-app.id}"
  port              = "80"
  protocol          = "HTTP"
  default_action {
    target_group_arn = "${aws_alb_target_group.nodejs-app.id}"
    type             = "forward"
  }
}

/*== CloudWatch Logs ==*/
resource "aws_cloudwatch_log_group" "ecs" {
  name = "tf-ecs-group/ecs-agent"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "tf-ecs-group/nodejs-app"
}