# Bluewing shared IaC

Bluewing uses Hashicorp Terraform as an Infrastructure as Code solution to reliably and repeatedly generate cloud resources used by both Bluewing applications (showcrew marketing website, etc) and supporting functionality (bluewing.co.nz).

The `bluewing.tf` file contained within this repository is used to deploy and manage core bluewing resources that are shared across the company. This includes the `bluewing` droplet that contains the bluewing marketing website, alongwith the showcrew marketing website.

Terraform is run inside a docker container using the hashicorp/terraform image. Shortcuts to run common terraform commands can be found in the associated `Makefile`.
