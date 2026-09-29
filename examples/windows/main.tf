module "naming" {
  source  = "codectl/naming/azure"
  version = "~> 0.1"

  suffix = ["demo"]
}

module "regions" {
  source  = "codectl/locations/azure"
  version = "~> 1.0"

  location = {
    primary = "westeurope"
  }
}

module "rg" {
  source  = "codectl/rg/azure"
  version = "~> 1.0"

  groups = {
    demo = {
      name     = module.naming.resource_group.name_unique
      location = module.regions.location.primary.name
    }
  }
}

module "network" {
  source  = "codectl/vnet/azure"
  version = "~> 1.0"

  vnet = {
    name                = module.naming.virtual_network.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    address_space       = ["10.18.0.0/16"]

    subnets = {
      internal = {
        address_prefixes = ["10.18.1.0/24"]
      }
    }
  }
}

module "kv" {
  source  = "codectl/kv/azure"
  version = "~> 1.0"

  vault = {
    name                = module.naming.key_vault.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    secrets = {
      random_string = {
        instance = {
          length  = 24
          special = false
        }
      }
    }
  }
}

module "scaleset" {
  source  = "codectl/vmss/azure"
  version = "~> 1.0"

  virtual_machine_scale_set = {
    sku            = "Standard_DS1_v2"
    instances      = 2
    admin_username = "adminuser"
    os_disk = {
      storage_account_type = "Standard_LRS"
    }
    type                 = "windows"
    name                 = module.naming.windows_virtual_machine_scale_set.name_unique
    computer_name_prefix = "vmssdemo"
    location             = module.rg.groups.demo.location
    resource_group_name  = module.rg.groups.demo.name

    source_image_reference = {
      offer     = "WindowsServer"
      publisher = "MicrosoftWindowsServer"
      sku       = "2022-Datacenter"
    }

    admin_password = module.kv.secrets.instance.value

    interfaces = {
      internal = {
        subnet  = module.network.subnets.internal.id
        primary = true
      }
    }
  }
}
