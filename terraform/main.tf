module "yc-vpc" {
  source = "git::https://github.com/terraform-yc-modules/terraform-yc-vpc.git"
  
  network_name = "k8s-vpc"
  network_description = "k8s-vpc"
  create_nat_gw = false
  create_vpc = true
  create_sg = false
  public_subnets = [
    {
      zone = "ru-central1-a",
      v4_cidr_blocks = ["10.10.0.0/24"]
    },
    {
      v4_cidr_blocks = ["10.20.0.0/24"],
      zone = "ru-central1-b"
    },
    {
      v4_cidr_blocks = ["10.30.0.0/24"],
      zone = "ru-central1-c"
    },
  ]
}

module "yc-kubernetes" {
  source = "git::https://github.com/terraform-yc-modules/terraform-yc-kubernetes.git"

  cluster_name = "kube-cluster"
  network_id = module.yc-vpc.vpc_id
  master_locations = [
    {
      zone = module.yc-vpc.public_subnets["10.10.0.0/24"].zone,
      subnet_id = module.yc-vpc.public_subnets["10.10.0.0/24"].subnet_id
    },
    {
      zone = module.yc-vpc.public_subnets["10.20.0.0/24"].zone,
      subnet_id = module.yc-vpc.public_subnets["10.20.0.0/24"].subnet_id
    },
    {
      zone = module.yc-vpc.public_subnets["10.30.0.0/24"].zone,
      subnet_id = module.yc-vpc.public_subnets["10.30.0.0/24"].subnet_id
    }
  ]
  node_groups = {
    "yc-k8s-ng-01" = {
      description = "Kubernetes nodes group 01"
      platform_id = "standard-v3"
      node_cores = 2
      node_memory = 4
      disk_type = "network-ssd"
      disk_size = 32

      nat = true
    
      node_locations   = [
        {
          zone      = module.yc-vpc.public_subnets["10.10.0.0/24"].zone
          subnet_id = module.yc-vpc.public_subnets["10.10.0.0/24"].subnet_id
        }
      ]

      node_labels   = {
        role        = "worker-01"
        environment = "prod"
      }
    }
  }
}