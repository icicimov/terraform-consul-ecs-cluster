/*=== OUTPUTS ===*/
output "autoscaling_notification_sns_topic" {
  value = "${aws_sns_topic.ecs_cluster_instances.id}"
}

output "nodejs-app_frontend_url" {
  value = "http://${aws_alb.nodejs-app.dns_name}"
}
