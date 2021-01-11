// Variables
variable "packages" {
  type    = list(string)
  default = [
    "curl",
    "unzip"
  ]
}

variable "node_exporter_version" {
  type    = string
  default = "1.0.1"
}

variable "prometheus_home" {
  type    = string
  default = "/opt/prometheus"
}

variable "prometheus_version" {
  type    = string
  default = "2.24.0"
}

variable "prometheus_user" {
  type    = string
  default = "prometheus"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

// Image
source "lxd" "prometheus-ubuntu-focal" {
  image        = "images:ubuntu/focal"
  output_image = "prometheus-ubuntu-focal"
  publish_properties = {
    description = "Hashicorp Prometheus - Ubuntu Focal"
  }
}

// Build
build {
  sources = ["source.lxd.prometheus-ubuntu-focal"]

  // Update and install packages
  provisioner "shell" {
    inline = [
      "apt-get update -qq",
      "DEBIAN_FRONTEND=noninteractive apt-get install -qq ${join(" ", var.packages)} < /dev/null > /dev/null"
    ]
  }

  // Install node_exporter
  provisioner "shell" {
    inline = [
      "curl -sLo - https://github.com/prometheus/node_exporter/releases/download/v${var.node_exporter_version}/node_exporter-${var.node_exporter_version}.linux-amd64.tar.gz | \n",
      "tar -zxf - --strip-component=1 -C /usr/local/bin/ node_exporter-${var.node_exporter_version}.linux-amd64/node_exporter"
    ]
  }

  // Create directories for Prometheus
  provisioner "shell" {
    inline = [
      "mkdir -p /etc/prometheus/tls ${var.prometheus_home}"
    ]
  }

  // Create Prometheus system user
  provisioner "shell" {
    inline = [
      "useradd --system --home ${var.prometheus_home} --shell /bin/false ${var.prometheus_user}"
    ]
  }

  // Create self-signed certificate
  provisioner "shell" {
    inline = [
      "openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout /etc/prometheus/tls/server.key -out /etc/prometheus/tls/server.crt -subj \"/CN=prometheus\""
    ]
  }

  // Install Prometheus
  provisioner "shell" {
    inline = [
      "curl -sLo - https://github.com/prometheus/prometheus/releases/download/v${var.prometheus_version}/prometheus-${var.prometheus_version}.linux-amd64.tar.gz | \n",
      "tar -zxf - --strip-component=1 -C /usr/local/bin/ prometheus-${var.prometheus_version}.linux-amd64/prometheus"
    ]
  }

  // Add Prometheus config
  provisioner "file" {
    source      = "files/etc/prometheus/prometheus.yaml"
    destination = "/etc/prometheus/prometheus.yaml"
  }

  // Add Prometheus default for systemd
  provisioner "file" {
    source      = "files/etc/default/prometheus"
    destination = "/etc/default/prometheus"
  }

  // Add Prometheus service
  provisioner "file" {
    source      = "files/etc/systemd/system/prometheus.service"
    destination = "/etc/systemd/system/prometheus.service"
  }

  // Set file ownership and enable the service
  provisioner "shell" {
    inline = [
      "chown -R ${var.prometheus_user} /etc/prometheus ${var.prometheus_home}",
      "systemctl enable prometheus"
    ]
  }
}
