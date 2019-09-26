# ecs.tf

resource "aws_ecs_cluster" "main" {
  name = "arc-cluster"
}

data "template_file" "arc_app" {
  template = file("./templates/ecs/arc_app.json.tpl")

  vars = {
    container_name    = var.container_name
    app_image         = var.app_image
    app_port          = var.app_port
    fargate_cpu       = var.fargate_cpu
    fargate_memory    = var.fargate_memory
    aws_region        = var.aws_region
    access_key_arn    = var.access_key_arn
    access_secret_arn = var.access_secret_arn
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.container_name}-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions    = data.template_file.arc_app.rendered
}

resource "aws_ecs_service" "main" {
  name            = var.arc_job_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.web.id
    container_name   = var.container_name
    container_port   = var.app_port
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.spark.id
    container_name   = var.container_name
    container_port   = 4040
  }
  depends_on = [aws_alb_listener.web, aws_alb_listener.spark, aws_iam_role_policy_attachment.ecs_task_execution_role]
}
