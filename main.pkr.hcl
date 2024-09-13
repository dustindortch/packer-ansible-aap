packer {
  required_plugins {
    amazon = {
      version = "~> 1.3"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/ansible"
    }
  }
  required_version = "~> 1.11"
}

data "amazon-ami" "rhel9" {
  region      = var.region
  filters     = var.ami_filter
  most_recent = true
  owners      = [ var.ami_owner ]
}

locals {
  ami_name = "${var.ami_name}_${formatdate("YYYY-MM-DD_hh-mm-ss",timestamp())}"
}

source "amazon-ebs" "img" {
  ami_name      = local.ami_name
  instance_type = var.instance_type
  region        = var.region
  source_ami    = data.amazon-ami.rhel9.id
  ssh_username  = var.ssh_username
}

build {
  name = var.ami_name

  hcp_packer_registry {
    bucket_name = var.ami_name
    description = "Base RHEL 9 AMI with Ansible Automation Platform installer package preloaded."

    bucket_labels = {
      owner   = "Dustin Dortch"
      os      = "RHEL"
      version = "9"
    }
  }

  provisioner "ansible" {
    playbook_file = "playbook.yml"
    sftp_command  = "/usr/libexec/openssh/sftp-server -e"

    ansible_env_vars = [
      "ANSIBLE_DEPRECATION_WARNINGS=False",
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_NOCOLOR=True",
      "ANSIBLE_NOCOWS=1"
    ]

    ansible_ssh_extra_args = ["-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa -o IdentitiesOnly=yes"]
    extra_arguments        = ["--scp-extra-args", "'-O'"]
  }

  sources = [
    "source.amazon-ebs.img"
  ]
}