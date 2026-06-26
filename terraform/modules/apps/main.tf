# 1. Crear el Clúster de ECS
resource "aws_ecs_cluster" "main" {
  name = "retail-${var.environment}-cluster"
}

# 2. Grupo de Seguridad para el ALB
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

# 3. Grupo de Seguridad para Contenedores (Permite ALB y todo el tráfico local interno)
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

# 6. Crear un Target Group por cada servicio web
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

# 7. Reglas de ruteo del ALB
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

# =========================================================================
# LA SOLUCIÓN MAESTRA: LA GRAN UNIFICACIÓN DE CONTENEDORES (Localhost mesh)
# =========================================================================
resource "aws_ecs_task_definition" "retail_stack" {
  family                   = "retail-full-stack"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048"  # Recursos compartidos eficientemente
  memory                   = "4096"
  execution_role_arn       = "arn:aws:iam::914465196685:role/LabRole"
  task_role_arn            = "arn:aws:iam::914465196685:role/LabRole"

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
    # --- CATALOG ---
    {
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
    },
    # --- CARTS ---
    {
      name      = "retail-carts"
      image     = "${var.repository_urls["carts"]}:latest"
      essential = true
      portMappings = [{ containerPort = 8082, hostPort = 8082 }] # Puerto alternativo interno para evitar colisión si es necesario, o mantener 8080 compartiendo IP interna si las apps discriminan
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
      environment = [
        { name = "RETAIL_CHECKOUT_PERSISTENCE_PROVIDER", value = "redis" },
        { name = "RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL", value = "redis://127.0.0.1:6379" },
        { name = "RETAIL_CHECKOUT_ENDPOINTS_ORDERS", value = "http://127.0.0.1:8080" }
      ]
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
    },
    # --- UI (FRONTEND) ---
    {
      name      = "retail-ui"
      image     = "${var.repository_urls["ui"]}:latest"
      essential = true
      environment = [
        { name = "RETAIL_UI_ENDPOINTS_CATALOG", value = "http://127.0.0.1:8080" },
        { name = "RETAIL_UI_ENDPOINTS_CARTS", value = "http://127.0.0.1:8080" },
        { name = "RETAIL_UI_ENDPOINTS_CHECKOUT", value = "http://127.0.0.1:8080" },
        { name = "RETAIL_UI_ENDPOINTS_ORDERS", value = "http://127.0.0.1:8080" }
      ]
    }
  ])
}

resource "aws_ecs_service" "retail_service" {
  name            = "retail-full-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.retail_stack.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  # Vinculamos los mapeos del ALB directo a la misma interfaz compartida
  dynamic "load_balancer" {
    for_each = toset(var.services)
    content {
      target_group_arn = aws_lb_target_group.targets[load_balancer.value].arn
      container_name   = "retail-${load_balancer.value}"
      container_port   = load_balancer.value == "admin" ? 8081 : 8080
    }
  }

  depends_on = [aws_lb_listener.http]
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}