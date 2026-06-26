# 1. Crear el Clúster de ECS con Service Connect activado
resource "aws_ecs_cluster" "main" {
  name = "retail-${var.environment}-cluster"
}

# Crear el Namespace de Cloud Map para Service Connect (Comunicación interna transparente)
resource "aws_service_discovery_http_namespace" "main" {
  name        = "retail.internal"
  description = "Namespace para intercomunicacion de microservicios"
}

# 2. Grupo de Seguridad para el ALB (Permite tráfico de Internet al puerto 80)
resource "aws_security_group" "alb" {
  name        = "retail-${var.environment}-alb-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Grupo de Seguridad para los Contenedores ECS
resource "aws_security_group" "ecs_tasks" {
  name        = "retail-${var.environment}-ecs-tasks-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. Crear el Application Load Balancer Público
resource "aws_lb" "main" {
  name               = "retail-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnets
}

# 5. Crear el Listener del ALB en el puerto 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port               = "80"
  protocol           = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets["ui"].arn
  }
}

# 6. Crear un Target Group por cada servicio mapeando sus puertos reales
resource "aws_lb_target_group" "targets" {
  for_each    = toset(var.services)
  name        = "tg-${each.value}"
  port        = each.value == "admin" ? 8081 : 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = each.value == "ui" ? "/" : "/health"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

# 7. Reglas de ruteo en el ALB
resource "aws_lb_listener_rule" "routing" {
  for_each     = toset([for s in var.services : s if s != "ui"])
  listener_arn = aws_lb_listener.http.arn
  priority     = index(var.services, each.value) + 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets[each.value].arn
  }

  condition {
    path_pattern {
      values = ["/api/${each.value}/*", "/${each.value}/*"]
    }
  }
}

# 8. Definición de Tareas y Servicios de ECS Fargate para las Apps
resource "aws_ecs_task_definition" "app" {
  for_each                 = toset(var.services)
  family                   = "retail-${each.value}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = (each.value == "admin" || each.value == "checkout") ? "512" : "256"
  memory                   = (each.value == "admin" || each.value == "checkout") ? "1024" : "512"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

  container_definitions = jsonencode([
    {
      name      = "retail-${each.value}"
      image     = "${var.repository_urls[each.value]}:latest"
      essential = true
      portMappings = [
        {
          name          = each.value
          containerPort = each.value == "admin" ? 8081 : 8080
          hostPort      = each.value == "admin" ? 8081 : 8080
        }
      ]

      environment = [
        { name = "RETAIL_UI_ENDPOINTS_CATALOG", value = "http://${aws_lb.main.dns_name}/api/catalog" },
        { name = "RETAIL_UI_ENDPOINTS_CARTS", value = "http://${aws_lb.main.dns_name}/api/carts" },
        { name = "RETAIL_UI_ENDPOINTS_CHECKOUT", value = "http://${aws_lb.main.dns_name}/api/checkout" },
        { name = "RETAIL_UI_ENDPOINTS_ORDERS", value = "http://${aws_lb.main.dns_name}/api/orders" },
        
        { name = "RETAIL_CHECKOUT_ENDPOINTS_ORDERS", value = "http://${aws_lb.main.dns_name}/api/orders" },
        
        # AJUSTE FIJO REDIS (Según tu configuration.ts)
        { name = "RETAIL_CHECKOUT_PERSISTENCE_PROVIDER", value = "redis" },
        { name = "RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL", value = "redis://retail-redis.retail.internal:6379" },

        # AJUSTE FIJO CATALOGO (Según tu config.go)
        { name = "RETAIL_CATALOG_PERSISTENCE_PROVIDER", value = "postgres" },
        { name = "RETAIL_CATALOG_PERSISTENCE_ENDPOINT", value = "retail-db.retail.internal:5432" },
        { name = "RETAIL_CATALOG_PERSISTENCE_DB_NAME", value = "retail" },
        { name = "RETAIL_CATALOG_PERSISTENCE_USER", value = "retailuser" },
        { name = "RETAIL_CATALOG_PERSISTENCE_PASSWORD", value = var.db_password },

        # AJUSTE FIJO ORDERS (Mismo patrón de Go)
        { name = "RETAIL_ORDERS_PERSISTENCE_PROVIDER", value = "postgres" },
        { name = "RETAIL_ORDERS_PERSISTENCE_ENDPOINT", value = "retail-db.retail.internal:5432" },
        { name = "RETAIL_ORDERS_PERSISTENCE_DB_NAME", value = "retail" },
        { name = "RETAIL_ORDERS_PERSISTENCE_USER", value = "retailuser" },
        { name = "RETAIL_ORDERS_PERSISTENCE_PASSWORD", value = var.db_password },

        { name = "DB_PASSWORD", value = var.db_password }
      ]
    }
  ])
}

resource "aws_ecs_service" "app" {
  for_each        = toset(var.services)
  name            = "retail-${each.value}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app[each.value].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.targets[each.value].arn
    container_name   = "retail-${each.value}"
    container_port   = each.value == "admin" ? 8081 : 8080
  }

  # Service Connect mapea el tráfico HTTP interno automáticamente
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn
  }

  depends_on = [aws_lb_listener.http]
}

# =========================================================================
# PERSISTENCIA: RETAIL-DB (PostgreSQL)
# =========================================================================
resource "aws_ecs_task_definition" "db" {
  family                   = "retail-db"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

  container_definitions = jsonencode([
    {
      name      = "retail-db"
      image     = "${var.repository_urls["db"]}:latest"
      essential = true
      portMappings = [
        {
          name          = "postgres"
          containerPort = 5432
          hostPort      = 5432
        }
      ]
      environment = [
        { name = "POSTGRES_DB", value = "retail" },
        { name = "POSTGRES_USER", value = "retailuser" },
        { name = "POSTGRES_PASSWORD", value = var.db_password }
      ]
    }
  ])
}

resource "aws_ecs_service" "db" {
  name            = "retail-db"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.db.family
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn
    client_alias {
      dns_name = "retail-db.retail.internal"
      port     = 5432
    }
  }
}

# =========================================================================
# PERSISTENCIA: RETAIL-REDIS
# =========================================================================
resource "aws_ecs_task_definition" "redis" {
  family                   = "retail-redis"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

  container_definitions = jsonencode([
    {
      name      = "retail-redis"
      image     = "redis:7-alpine"
      essential = true
      portMappings = [
        {
          name          = "redis"
          containerPort = 6379
          hostPort      = 6379
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "redis" {
  name            = "retail-redis"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.redis.family
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn
    client_alias {
      dns_name = "retail-redis.retail.internal"
      port     = 6379
    }
  }
}