terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.20.0"
    }
  }
}

# This is provided by the docker-compose.yaml environment that the terraform plugin runs in.
variable "do_token" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "The token retrieved from DigitalOcean to be used to interact with their API. Retrieve from here: https://cloud.digitalocean.com/account/api/tokens?i=aa3c54"
}

provider "digitalocean" {
  token = var.do_token
}

# The "Bluewing" project that is used to contain bluewing-general resources.
data "digitalocean_project" "bluewing-project" {
  name = "Bluewing"
}

data "digitalocean_tag" "bluewing-tag" {
  name = "bluewing"
}

# The `bluewing-vpn` droplet that contains our instance of OpenVPN to connect to bluewing resources.
data "digitalocean_droplet" "bluewing-vpn" {
  name = "bluewing-vpn"
}

# Retrieves the VPC that the `bluewing` droplet will be assigned to.
data "digitalocean_vpc" "default-sfo3" {
  region = "sfo3"
}

# Retrieves the SSH key that the `bluewing` droplet will be associated with.
data "digitalocean_ssh_key" "luke-ssh-key" {
  name = "lukedavia@icloud.com"
}

resource "digitalocean_droplet" "bluewing" {
  image       = "ubuntu-22-04-x64"
  name        = "bluewing"
  region      = "sfo3"
  size        = "s-1vcpu-1gb"
  backups     = false
  monitoring  = true
  ipv6        = true
  vpc_uuid    = data.digitalocean_vpc.default-sfo3.id
  ssh_keys    = [data.digitalocean_ssh_key.luke-ssh-key.fingerprint]
  resize_disk = false
  user_data   = file("provision.sh")
  tags        = [data.digitalocean_tag.bluewing-tag.name]
}

# Attach bluewing droplet to the bluewing project.
resource "digitalocean_project_resources" "bluewing-bluewing" {
  project = data.digitalocean_project.bluewing-project.id
  resources = [
    digitalocean_droplet.bluewing.urn
  ]
}

# Define a firewall that prevents SSH access to resources unless the originating IP 
# is from the `bluewing-vpn` droplet. Allow in all other HTTP/HTTPS traffic, and allow all outbound traffic.
# The `bluewing` droplet is then attached to this rule.
resource "digitalocean_firewall" "VpnRequiredForSshTraffic" {
  name        = "VpnRequiredForSshTraffic"
  droplet_ids = [digitalocean_droplet.bluewing.id]

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol    = "tcp"
    port_range  = "22"
    source_tags = ["bluewing-vpn"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
