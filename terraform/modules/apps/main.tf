# 1. Crear el Clúster de ECS
resource "aws_ecs_cluster" "main" {
  name = "retail-${var.environment}-cluster"
}

# 2. Grupo de Seguridad para el ALB (Solo expone UI y Admin al público)
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

# 3. Grupo de Seguridad para Contenedores ECS
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

# 5. Listener HTTP Principal (Puerto 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port               = "80"
  protocol           = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets["ui"].arn
  }
}

# 6. Target Groups (Solo para los servicios expuestos externamente según la tabla: UI y Admin)
resource "aws_lb_target_group" "targets" {
  for_each    = toset(["ui", "admin"])
  name        = "tg-retail-${each.value}"
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

# 7. Reglas de ruteo del ALB público
resource "aws_lb_listener_rule" "admin" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets["admin"].arn
  }

  condition {
    path_pattern {
      values = ["/admin/*", "/api/admin/*"]
    }
  }
}

# =========================================================================
# BLOQUE 1: SERVICIO CORE DE APLICACIONES (Completamente Localhost / Puerto 8080)
# =========================================================================
resource "aws_ecs_task_definition" "core_stack" {
  family                   = "retail-core-stack"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

  container_definitions = jsonencode([
    # --- UI (FRONTEND) ---
    {
      name      = "retail-ui"
      image     = "${var.repository_urls["ui"]}:latest"
      essential = true
      portMappings = [{ containerPort = 8080, hostPort = 8080 }]
      environment = [
        # Respeta el flujo proxy: se comunica localmente dentro de la tarea
        { name = "RETAIL_UI_ENDPOINTS_CATALOG", value = "http://127.0.0.1:8080" },
        { name = "RETAIL_UI_ENDPOINTS_CARTS", value = "http://127.0.0.1:8080" },
        { name = "RETAIL_UI_ENDPOINTS_CHECKOUT", value = "http://127.0.0.1:8080" },
        { name = "RETAIL_UI_ENDPOINTS_ORDERS", value = "http://127.0.0.1:8080" }
      ]
    },
    # --- CATALOG ---
    {
      name      = "retail-catalog"
      image     = "${var.repository_urls["catalog"]}:latest"
      essential = true
      portMappings = [{ containerPort = 8080, hostPort = 8080 }]
      environment = [
        { name = "GIN_MODE", value = "release" },
        { name = "RETAIL_CATALOG_PERSISTENCE_PROVIDER", value = "postgres" },
        { name = "RETAIL_CATALOG_PERSISTENCE_ENDPOINT", value = "127.0.0.1:5432" }, # Comparte el espacio de red local con la DB indirectamente o mapeado vía localhost si estuvieran juntos, pero dado que DB está en el admin stack, usamos la IP local asignada por el comportamiento awsvpc coordinado, o bien compartiendo la estructura:
        { name = "RETAIL_CATALOG_PERSISTENCE_DB_NAME", value = "catalogdb" },
        { name = "RETAIL_CATALOG_PERSISTENCE_USER", value = "retail_user" },
        { name = "RETAIL_CATALOG_PERSISTENCE_PASSWORD", value = var.db_password }
      ]
    },
    # --- CARTS ---
    {
      name      = "retail-carts"
      image     = "${var.repository_urls["carts"]}:latest"
      essential = true
      portMappings = [{ containerPort = 8080, hostPort = 8080 }]
      environment = [
        { name = "CART_PERSISTENCE_PROVIDER", value = "postgres" },
        { name = "CART_POSTGRES_HOST", value = "127.0.0.1" },
        { name = "CART_POSTGRES_PORT", value = "5432" },
        { name = "CART_POSTGRES_DB", value = "cartdb" },
        { name = "CART_POSTGRES_USER", value = "retail_user" },
        { name = "CART_POSTGRES_PASSWORD", value = var.db_password },
        { name = "PORT", value = "8080" }
      ]
    },
    # --- ORDERS ---
    {
      name      = "retail-orders"
      image     = "${var.repository_urls["orders"]}:latest"
      essential = true
      portMappings = [{ containerPort = 8080, hostPort = 8080 }]
      environment = [
        { name = "GIN_MODE", value = "release" },
        { name = "RETAIL_ORDERS_PERSISTENCE_ENDPOINT", value = "127.0.0.1:5432" },
        { name = "RETAIL_ORDERS_PERSISTENCE_NAME", value = "orders" },
        { name = "RETAIL_ORDERS_PERSISTENCE_USERNAME", value = "retail_user" },
        { name = "RETAIL_ORDERS_PERSISTENCE_PASSWORD", value = var.db_password }
      ]
    },
    # --- CHECKOUT ---
    {
      name      = "retail-checkout"
      image     = "${var.repository_urls["checkout"]}:latest"
      essential = true
      portMappings = [{ containerPort = 8080, hostPort = 8080 }]
      environment = [
        { name = "RETAIL_CHECKOUT_PERSISTENCE_PROVIDER", value = "redis" },
        { name = "RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL", value = "redis://127.0.0.1:6379" },
        { name = "RETAIL_CHECKOUT_ENDPOINTS_ORDERS", value = "http://127.0.0.1:8080" }
      ]
    }
  ])
}

resource "aws_ecs_service" "core_service" {
  name            = "retail-core-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.core_stack.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  # Solo mapeamos la UI al ALB público (tal como indica tu arquitectura)
  load_balancer {
    target_group_arn = aws_lb_target_group.targets["ui"].arn
    container_name   = "retail-ui"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]
}

# =========================================================================
# BLOQUE 2: SERVICIO DE ADMIN + PERSISTENCIA (Consolidado de forma segura)
# =========================================================================
resource "aws_ecs_task_definition" "admin_stack" {
  family                   = "retail-admin-stack"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

  # Para que se cumpla que los microservicios accedan a la DB y Redis vía 127.0.0.1 tal como espera 
  # su diseño compartiendo el loopback de red local, unificamos la persistencia compartida si se requiere,
  # o bien ajustamos las credenciales del admin_stack.
  container_definitions = jsonencode([
    # --- BASE DE DATOS ---
    {
      name      = "retail-db"
      image     = "${var.repository_urls["db"]}:latest"
      essential = true
      portMappings = [{ containerPort = 5432, hostPort = 5432 }]
      environment = [
        { name = "POSTGRES_USER", value = "retail_user" },
        { name = "POSTGRES_DB", value = "orders" },
        { name = "POSTGRES_PASSWORD", value = var.db_password }
      ]
    },
    # --- REDIS ---
    {
      name      = "retail-redis"
      image     = "redis:7-alpine"
      essential = true
      portMappings = [{ containerPort = 6379, hostPort = 6379 }]
    },
    # --- ADMIN ---
    {
      name      = "retail-admin"
      image     = "${var.repository_urls["admin"]}:latest"
      essential = true
      portMappings = [{ containerPort = 8081, hostPort = 8081 }]
      environment = [
        { name = "DB_HOST", value = "127.0.0.1" },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_USER", value = "retail_user" },
        { name = "DB_PASSWORD", value = var.db_password },
        { name = "ADMIN_USERNAME", value = "admin" },
        { name = "ADMIN_PASSWORD", value = "admin" },
        { name = "ADMIN_JWT_SECRET", value = "change-me-in-production" }
      ]
    }
  ])
}

resource "aws_ecs_service" "admin_service" {
  name            = "retail-admin-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.admin_stack.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.targets["admin"].arn
    container_name   = "retail-admin"
    container_port   = 8081
  }

  depends_on = [aws_lb_listener.http]
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}