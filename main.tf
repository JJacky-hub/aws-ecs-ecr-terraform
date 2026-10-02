# ==========================================
# ECR REPOSITORY FOR DOCKER IMAGES
# ==========================================

resource "aws_ecr_repository" "app_repo" {
  name                 = "${var.app_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  # Автоматическое сканирование образа на уязвимости (CVE) при каждом push
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ==========================================
# CLOUDWATCH LOG GROUP FOR CONTAINER LOGS
# ==========================================

# ECS будет отправлять сюда stdout/stderr логов из контейнера
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.app_name}-${var.environment}"
  retention_in_days = 7 # Хранить логи 7 дней, чтобы не переплачивать за дисковое пространство

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ==========================================
# IAM EXECUTION ROLE FOR ECS
# ==========================================

# ECS Task Execution Role позволяет AWS забирать образ из ECR и отправлять логи в CloudWatch
data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name               = "${var.app_name}-ecs-execution-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==========================================
# NETWORKING (DEFAULT VPC & SECURITY GROUP)
# ==========================================

# Используем стандартную VPC для простоты
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group для закрытия/открытия портов контейнера
resource "aws_security_group" "ecs_sg" {
  name        = "${var.app_name}-ecs-sg-${var.environment}"
  description = "Allow HTTP inbound traffic for ECS task"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    ="-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ==========================================
# ECS CLUSTER, TASK DEFINITION & SERVICE
# ==========================================

# 1. ECS Кластер (логическая группа для работы контейнеров)
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster-${var.environment}"
}

# 2. Task Definition (спецификация: сколько CPU/RAM выдать, какой Docker-образ брать)
resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.app_name}-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 512 MB RAM
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# 3. ECS Service (контроллер, который следит, чтобы контейнер всегда был запущен)
resource "aws_ecs_service" "app_service" {
  name            = "${var.app_name}-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
    
  # ДОБАВЛЯЕМ ЭТОТ БЛОК:
  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = var.app_name
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}  

# ==========================================
# APPLICATION LOAD BALANCER (ALB)
# ==========================================

# 1. Сам балансировщик нагрузки
resource "aws_lb" "main" {
  name               = "${var.app_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 2. Target Group (группа назначения для Fargate)
resource "aws_lb_target_group" "app_tg" {
  name        = "${var.app_name}-tg-${var.environment}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # Для Fargate обязательно указывается тип 'ip'

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    matcher             = "200"
  }
}

# 3. ALB Listener (приемник HTTP трафика)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
