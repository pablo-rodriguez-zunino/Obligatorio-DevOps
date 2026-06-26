# 1. Crear el Clúster de ECS
resource "aws_ecs_cluster" "main" {
  name = "retail-${var.environment}-cluster"
}

# 2. Grupo de Seguridad para el ALB público
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

# 3. Grupo de Seguridad para las Tareas de ECS
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

# 5. Listener HTTP Principal (Puerto 80) -> Por defecto va a la UI
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port               = "80"
  protocol           = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets["ui"].arn
  }
}

# 6. Target Groups limitados a 4 para cumplir la restricción de la cuenta estudiante
resource "aws_lb_target_group" "targets" {
  for_each    = toset(["ui", "catalog", "carts", "orders"])
  name        = "tg-ret-${each.value}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    # IMPORTANTE: Apunta a la ruta real /health de express y backends de go/python
    path                = "/health" 
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    matcher             = "200-399"
  }
}

# 7. Reglas de ruteo del ALB para que los microservicios se expongan bajo sub-rutas internas
resource "aws_lb_listener_rule" "routing" {
  for_each     = toset(["catalog", "carts", "orders"])
  listener_arn = aws_lb_listener.http.arn
  priority     = each.value == "catalog" ? 10 : each.value == "carts" ? 20 : 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets[each.value].arn
  }

  condition {
    path_pattern {
      values = ["/${each.value}/*", "/api/${each.value}/*"]
    }
  }
}

# =========================================================================
# CATALOG SERVICE
# =========================================================================
resource "aws_ecs_task_definition" "catalog" {
  family                   = "retail-catalog"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

  container_definitions = jsonencode([{
    name      = "retail-catalog"
    image     = "${var.repository_urls["catalog"]}:latest"
    essential = true
    portMappings = [{ containerPort = 8080, hostPort = 8080 }]
    environment = [
      { name = "GIN_MODE", value = "release" },
      { name = "RETAIL_CATALOG_PERSISTENCE_PROVIDER", value = "postgres" },
      { name = "RETAIL_CATALOG_PERSISTENCE_ENDPOINT", value = "127.0.0.1:5432" },
      { name = "RETAIL_CATALOG_PERSISTENCE_DB_NAME", value = "catalogdb" },
      { name = "RETAIL_CATALOG_PERSISTENCE_USER", value = "retail_user" },
      { name = "RETAIL_CATALOG_PERSISTENCE_PASSWORD", value = var.db_password }
    ]
  }])
}

resource "aws_ecs_service" "catalog" {
  name            = "retail-catalog-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.catalog.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnets # ◄ CAMBIADO A SUB-REDES PÚBLICAS
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.targets["catalog"].arn
    container_name   = "retail-catalog"
    container_port   = 8080
  }
}

# =========================================================================
# CARTS SERVICE
# =========================================================================
resource "aws_ecs_task_definition" "carts" {
  family                   = "retail-carts"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

  container_definitions = jsonencode([{
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
  }])
}

resource "aws_ecs_service" "carts" {
  name            = "retail-carts-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.carts.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnets # ◄ CAMBIADO A SUB-REDES PÚBLICAS
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.targets["carts"].arn
    container_name   = "retail-carts"
    container_port   = 8080
  }
}

# =========================================================================
# ORDERS SERVICE
# =========================================================================
resource "aws_ecs_task_definition" "orders" {
  family                   = "retail-orders"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

  container_definitions = jsonencode([{
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
  }])
}

resource "aws_ecs_service" "orders" {
  name            = "retail-orders-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.orders.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnets # ◄ CAMBIADO A SUB-REDES PÚBLICAS
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.targets["orders"].arn
    container_name   = "retail-orders"
    container_port   = 8080
  }
}

# =========================================================================
# STACK PRINCIPAL: UI + CHECKOUT + PERSISTENCIA INTEGRADA
# =========================================================================
resource "aws_ecs_task_definition" "ui_stack" {
  family                   = "retail-ui-stack"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

  container_definitions = jsonencode([
    {
      name      = "retail-ui"
      image     = "${var.repository_urls["ui"]}:latest"
      essential = true
      portMappings = [{ containerPort = 8080, hostPort = 8080 }]
      environment = [
        { name = "RETAIL_UI_ENDPOINTS_CATALOG", value = "http://${aws_lb.main.dns_name}/api/catalog" },
        { name = "RETAIL_UI_ENDPOINTS_CARTS", value = "http://${aws_lb.main.dns_name}/api/carts" },
        { name = "RETAIL_UI_ENDPOINTS_ORDERS", value = "http://${aws_lb.main.dns_name}/api/orders" },
        { name = "RETAIL_UI_ENDPOINTS_CHECKOUT", value = "http://127.0.0.1:8085" } 
      ]
    },
    {
      name      = "retail-checkout"
      image     = "${var.repository_urls["checkout"]}:latest"
      essential = true
      portMappings = [{ containerPort = 8085, hostPort = 8085 }]
      environment = [
        { name = "PORT", value = "8085" },
        { name = "RETAIL_CHECKOUT_PERSISTENCE_PROVIDER", value = "redis" },
        { name = "RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL", value = "redis://127.0.0.1:6379" },
        { name = "RETAIL_CHECKOUT_ENDPOINTS_ORDERS", value = "http://${aws_lb.main.dns_name}/api/orders" }
      ]
    },
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
    {
      name      = "retail-redis"
      image     = "redis:7-alpine"
      essential = true
      portMappings = [{ containerPort = 6379, hostPort = 6379 }]
    }
  ])
}

resource "aws_ecs_service" "ui_service" {
  name            = "retail-ui-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ui_stack.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnets # ◄ CAMBIADO A SUB-REDES PÚBLICAS
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.targets["ui"].arn
    container_name   = "retail-ui"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]
}

# =========================================================================
# STACK AISLADO: ADMIN PANEL
# =========================================================================
resource "aws_ecs_task_definition" "admin" {
  family                   = "retail-admin"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

  container_definitions = jsonencode([{
    name      = "retail-admin"
    image     = "${var.repository_urls["admin"]}:latest"
    essential = true
    portMappings = [{ containerPort = 8080, hostPort = 8080 }]
    environment = [
      { name = "PORT", value = "8080" },
      { name = "DB_HOST", value = "127.0.0.1" }, 
      { name = "DB_PORT", value = "5432" },
      { name = "DB_USER", value = "retail_user" },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "ADMIN_USERNAME", value = "admin" },
      { name = "ADMIN_PASSWORD", value = "admin" },
      { name = "ADMIN_JWT_SECRET", value = "change-me-in-production" }
    ]
  }])
}

resource "aws_ecs_service" "admin_service" {
  name            = "retail-admin-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.admin.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnets # ◄ CAMBIADO A SUB-REDES PÚBLICAS
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }
}

# EXPONER EL OUTPUT COMPATIBLE CON EL MAIN RAÍZ
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "DNS del Load Balancer"
}

# =========================================================================
# INTEGRACIÓN DEL MÓDULO DE MONITOREO DINÁMICO (CLOUDWATCH)
# =========================================================================
module "monitoring" {
  source   = "../cloudwatch"
  for_each = toset(["ui", "catalog", "carts", "orders"])

  # Variables básicas del entorno
  app_name    = "retail-${each.value}"
  environment = var.environment
  aws_region  = "us-east-1" # Cambiar por tu región si es distinta (ej. var.aws_region)
  alarm_email = "tu-email-de-estudiante@ort.edu.uy" # ◄ PONÉ TU EMAIL ACÁ PARA LAS ALERTAS

  # Parámetro dinámico del Cluster
  cluster_name = aws_ecs_cluster.main.name

  # Mapeo condicional para obtener el ServiceName exacto de cada recurso ECS
  service_name = each.value == "ui" ? aws_ecs_service.ui_service.name : (
                 each.value == "catalog" ? aws_ecs_service.catalog.name : (
                 each.value == "carts" ? aws_ecs_service.carts.name : aws_ecs_service.orders.name))

  # Filtros nativos extraídos directamente del ALB y Target Groups
  alb_arn_suffix           = aws_lb.main.arn_suffix
  target_group_arn_suffix = aws_lb_target_group.targets[each.value].arn_suffix

  # Umbrales configurados por defecto en tus variables (o podés personalizarlos acá)
  cpu_threshold             = 80
  memory_threshold          = 80
  error_5xx_threshold       = 10
  response_time_threshold   = 2
  unhealthy_hosts_threshold = 1
}

# =========================================================================
# SECCIÓN 7: SERVICIO SERVERLESS (AWS LAMBDA INTEGRADO A ALERTAS)
# =========================================================================
module "serverless_monitoring" {
  source = "../serverless"

  app_name      = "retailStore"
  environment   = var.environment
  
  # Nos colgamos dinámicamente del output de SNS del monitoreo de la UI
  sns_topic_arn = module.monitoring["ui"].sns_topic_arn
}