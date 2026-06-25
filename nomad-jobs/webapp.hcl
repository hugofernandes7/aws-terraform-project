variable "IMAGE_TAG" {
  default = "latest"
}

variable "DOCKER_TOKEN" {
  default = ""
}

variable "FQDN" {
  default = "example.myftp.org"
}

job "webapp" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 2

    network {
      port "http" {
        static = 8080
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    task "webapp" {
      driver = "docker"

      config {
        image = "maciel04/webapp:${var.IMAGE_TAG}"
        network_mode = "host"
        auth {
          username = "maciel04"
          password = "${var.DOCKER_TOKEN}"
        }


        volumes = [
          "local/default.conf:/etc/nginx/conf.d/default.conf"
        ]
      }

      env {
        FQDN ="${var.FQDN}"
      }

      template {
        data = <<TMPL
        
server {
    listen 8080 default_server;
    server_name _;

    location / {
        alias /static_files/goaccess/;
        index report.html;
    }

    location /ws {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass http://127.0.0.1:7890;
        proxy_buffering off;
        proxy_read_timeout 7d;
    }
}
TMPL
        destination = "local/default.conf"
      }

      resources {
        cpu    = 256
        memory = 256
      }
    }
  }
}
