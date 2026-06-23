module retail-store/catalog

go 1.24.0

toolchain go1.24.5

require (
    github.com/gin-gonic/gin v1.10.1
    github.com/sethvargo/go-envconfig v0.1.1
    github.com/zsais/go-gin-prometheus v0.1.0
    go.opentelemetry.io/otel v1.37.0
    go.opentelemetry.io/otel/exporters/otlp/otlptrace v1.37.0
    go.opentelemetry.io/otel/sdk v1.37.0
    gorm.io/driver/postgres v1.6.0
    gorm.io/driver/sqlite v1.5.7
    gorm.io/gorm v1.25.12
)

require (
    github.com/bytedance/sonic v1.12.7 // indirect
    github.com/bytedance/sonic/loader v0.2.3 // indirect
    github.com/cenkalti/backoff/v5 v5.0.2 // indirect
    github.com/cloudwego/base64x v0.1.5 // indirect
    github.com/gabriel-vasile/mimetype v1.4.8 // indirect
    github.com/go-logr/logr v1.4.3 // indirect
    github.com/go-logr/stdr v1.2.2 // indirect
    github.com/google/uuid v1.6.0 // indirect
    github.com/grpc-ecosystem/grpc-gateway/v2 v2.27.1 // indirect
    github.com/jackc/pgpassfile v1.0.0 // indirect
    github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
    github.com/jackc/pgx/v5 v5.6.0 // indirect
    github.com/jackc/puddle/v2 v2.2.2 // indirect
    github.com/jinzhu/inflection v1.0.0 // indirect
    github.com/jinzhu/now v1.1.5 // indirect
    github.com/klauspost/compress v1.17.11 // indirect
    github.com/klauspost/cpuid/v2 v2.2.9 // indirect
    github.com/mattn/go-sqlite3 v1.14.24 // indirect
    github.com/munnerz/goautoneg v0.0.0-20191010083416-a7dc8b61c822 // indirect
    github.com/prometheus/client_golang v1.20.5 // indirect
    github.com/twitchyliquid64/golang-asm v0.15.1 // indirect
    go.opentelemetry.io/auto/sdk v1.1.0 // indirect
    go.opentelemetry.io/otel/metric v1.37.0 // indirect
    go.opentelemetry.io/otel/trace v1.37.0 // indirect
    go.opentelemetry.io/proto/otlp v1.7.0 // indirect
    golang.org/x/arch v0.13.0 // indirect
    golang.org/x/sync v0.18.0 // indirect
    google.golang.org/genproto/googleapis/api v0.0.0-20250603155806-513f23925822 // indirect
    google.golang.org/genproto/googleapis/rpc v0.0.0-20250603155806-513f23925822 // indirect
    google.golang.org/grpc v1.73.0 // indirect
)

require (
    github.com/beorn7/perks v1.0.1 // indirect
    github.com/cespare/xxhash/v2 v2.3.0 // indirect
    github.com/gin-contrib/sse v1.0.0 // indirect
    github.com/go-playground/locales v0.14.1 // indirect
    github.com/go-playground/universal-translator v0.18.1 // indirect
    github.com/go-playground/validator/v10 v10.24.0 // indirect
    github.com/goccy/go-json v0.10.4 // indirect
    github.com/json-iterator/go v1.1.12 // indirect
    github.com/leodido/go-urn v1.4.0 // indirect
    github.com/mattn/go-isatty v0.0.20 // indirect
    github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
    github.com/modern-go/reflect2 v1.0.2 // indirect
    github.com/pelletier/go-toml/v2 v2.2.3 // indirect
    github.com/prometheus/client_model v0.6.1 // indirect
    github.com/prometheus/common v0.62.0 // indirect
    github.com/prometheus/procfs v0.15.1 // indirect
    github.com/sirupsen/logrus v1.9.3 // indirect
    github.com/ugorji/go/codec v1.2.12 // indirect
    go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin v0.59.0
    go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp v1.37.0
    golang.org/x/crypto v0.45.0 // indirect
    golang.org/x/net v0.47.0 // indirect
    golang.org/x/sys v0.38.0 // indirect
    golang.org/x/text v0.31.0 // indirect
    google.golang.org/protobuf v1.36.6 // indirect
    gopkg.in/yaml.v3 v3.0.1 // indirect
    gorm.io/plugin/opentelemetry v0.1.12
)

// Forzamos el parche de seguridad para Trivy
replace (
    github.com/jackc/pgx/v5 => github.com/jackc/pgx/v5 v5.9.0
    google.golang.org/grpc => google.golang.org/grpc v1.79.3
)