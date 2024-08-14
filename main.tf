##########################################################################################################################################
#####Create a project with Edgeview Policy################################################################################################
resource "zedcloud_project" "tf_toi_project_1" {
  name            = "ZEDEDA-TOI-DEMO"
  title           = "ZEDEDA-TOI-DEMO"
  type            = "TAG_TYPE_PROJECT"
  edgeview_policy {
      type          = "POLICY_TYPE_EDGEVIEW"
    edgeview_policy {
      access_allow_change = true
      edgeview_allow = true
      edgeviewcfg {
        app_policy {
          allow_app = true
        }
        dev_policy {
          allow_dev = true
        }
        jwt_info {
          disp_url = "zedcloud.gmwtus.zededa.net/api/v1/edge-view"
          allow_sec = 18000
          num_inst = 1
          encrypt = true
        }
        ext_policy {
          allow_ext = true
        }
      }
      max_expire_sec = 2592000
      max_inst = 3
    }
  }
}

##########################################################################################################################################
##Creates a datastore
resource "zedcloud_datastore" "tf_toi_ds" {
  ds_fqdn = "http://xx.xx.xx.xx"                                  ##### This is your local datastore IP or Azure Blog URL
  ds_type = "DATASTORE_TYPE_HTTP"
  name    = "TOI-DATASTORE"
  title   = "TOI-DATASTORE"
  ds_path = "iso"                                                 ###### Path of the url http://xx.xx.xx.xx/iso 
  project_access_list = [zedcloud_project.tf_toi_project_1.id]    ###### Projects you want to allow access
}

#############################################################################################################################################
########################## IMAGES ###########################################################################################################
### create FORTIGATE Image
resource "zedcloud_image" "tf_fortigate_image" {
  datastore_id = zedcloud_datastore.tf_toi_ds.id                  ###### This points to the datastore created above .id line 36
  image_type = "IMAGE_TYPE_APPLICATION"
  image_arch = "AMD64"
  image_format = "QCOW2"
  image_sha256 = "0e275df6f35b3139d4988afcf4ddd0e3cc9fcf88320877efe0dfd17febe75147"
  image_size_bytes =  100728832
  name = "fortios-7.4.3.qcow2"
  title = "fortios-7.4.3.qcow2"
  project_access_list = [zedcloud_project.tf_toi_project_1.id ]
  image_rel_url = "fortios-7.4.3.qcow2"

  depends_on = [ zedcloud_datastore.tf_toi_ds ]                   ###### I added a dependency to this image on the datastore line 36
}

#################Creat Fortigate ISO pointer ################################################################################################
resource "zedcloud_image" "tf_forti_lic_iso" {                    ###### This iso is used to bootstrap Fortigate config/license
  datastore_id = zedcloud_datastore.tf_toi_ds.id
  image_arch = "AMD64"
  image_format = "RAW"                                            ###### RAW because its an ISO
  name = "forti-fw-bootstrap.iso"
  title = "forti-fw-bootstrap.iso"
  image_rel_url = "forti-fw-bootstrap.iso"
  image_sha256 = "d067f6749cf939303006d54fb32825a1cb2ef6b3e45b4cd68000fce66aeeecf0"
  image_size_bytes = 380928
  image_type = "IMAGE_TYPE_APPLICATION"
  project_access_list = [zedcloud_project.tf_toi_project_1.id]

  depends_on = [ zedcloud_datastore.tf_toi_ds ]
}

################## Create UBUNTU image #######################################################################################################
resource "zedcloud_image" "tf_ubuntu_image" {
  datastore_id = zedcloud_datastore.tf_toi_ds.id
  image_type = "IMAGE_TYPE_APPLICATION"
  image_arch = "AMD64"
  image_format = "QCOW2"
  image_sha256 = "c8297d73ab524f33ded309e1f4fb9febdb95ecd66d85a648987bb3432aef6ebe"
  image_size_bytes =  489684992
  name = "ubuntu-noble-24.4"
  title = "ubuntu-noble-24.4"
  project_access_list = [zedcloud_project.tf_toi_project_1.id ]
  image_rel_url = "noble-server-cloudimg-amd64.img"

  depends_on = [ zedcloud_datastore.tf_toi_ds ]
}

#############################################################################################################################################
#############################Creates FORTIGATE APP  ########################################################################
resource "zedcloud_application" "tf_edge_app_fortigate_sw_eth0" {
  name = "FORTINET-7.4.3"
  title = "FORTINET-7.4.3"
  networks = 3                                                            ###### Number of vnics instance will have
  cpus = 1                                                                ###### Number of vcpus
  memory = 2000000                                                        ###### RAM/Memory alloted to the VM
  storage = 20971520                                                      ###### How much disk alloted to the VM
  manifest {
    ac_kind = "VMManifest"
    ac_version = "1.2.0"
    name = "FORTINE-7.4.3"
  owner {
    user = "Manny Calero"
    company = "Zededa"
    website = "www.zededa.com"
    email = "manny@zededa.com"
  }
  desc {
    app_category = "APP_CATEGORY_UNSPECIFIED"
    category = "APP_CATEGORY_SECURITY"
    } 
  images {
    imagename = zedcloud_image.tf_fortigate_image.name                      ###### This points to the image name created in line 49
    imageid = zedcloud_image.tf_fortigate_image.id                          ###### This points to the image id created in line 49
    imageformat = "QCOW2"
    cleartext = false
    drvtype = "HDD"
    ignorepurge = true
    maxsize = 20971520                                                      ###### Same as storage line 104
    target = "Disk"
 
    }
  images {
    imagename = zedcloud_image.tf_forti_lic_iso.name                        ###### This points to the image ISO name created in line 65
    imageid = zedcloud_image.tf_forti_lic_iso.id                            ###### This points to the image ISO id created in line 65
    imageformat = "RAW"                                                     ###### Type raw since its an ISO
    cleartext = false
    drvtype = "CDROM"
    ignorepurge = true
    maxsize = 1097152                                                       ###### Because its an ISO I give it around 1Gig
    target = "Disk"
    }
  interfaces {
    name = "eth0"
    type = ""
    directattach = false
    privateip = false
   acls {                                                                    ##### Equivalent of an outbound rule when creating an app Web UI
      matches {   
        type = "ip"
        value = "0.0.0.0/0"
      }
    }
    acls { 
      matches {                                                               ##### Equivalent of an inbound rule
        type = "ip"
        value = "0.0.0.0/0"
      }
      actions {
        portmap = true
        portmapto {
          app_port = 22                                                       ##### Map application port 22                                   
        }
      }
      matches {
        type = "protocol"               
        value = "tcp"                                                         ##### Matching TCP protocol
      }
      matches {
        type = "lport"
        value = 8222                                                          ##### External port mapping to internal app port on line 159 from outside EVE)
     }
      matches {
        type = "ip"
        value = "0.0.0.0/0"
     }
    }
        acls { 
      matches {                                                               ##### Another rule for a different inbound mapping
        type = "ip"
        value = "0.0.0.0/0"
      }
      actions {
        portmap = true
        portmapto {
          app_port = 443                                                      ##### Applications port (internal EVE)
        }
      }
      matches {
        type = "protocol"
        value = "tcp"
      }
      matches {
        type = "lport"
        value = 8443                                                         ##### External edge port maps to internal port line 183
     }
      matches {
        type = "ip"
        value = "0.0.0.0/0"
     }
    }
   }
  interfaces {
    name = "eth1"
    type = ""
    directattach = false
    privateip = false
      acls {
        matches { ### Outbound rule
          type = "ip"
          value = "0.0.0.0/0"
      }
    }
   }
  interfaces {
    name = "eth2"
    type = ""
    directattach = false
    privateip = false
      acls {
        matches { ### Outbound rule
          type = "ip"
          value = "0.0.0.0/0"
        }
      }
   }
  vmmode = "HV_HVM"
  enablevnc = true

  resources {
    name = "resourceType"
    value = "custom"
  }
  resources {
    name = "cpus"
    value = 1
  }
  resources {
    name = "memory"
    value = 2000000
  }
  resources {
    name = "storage"
    value = 20971520
  }
  configuration {
    custom_config {
      add = true
      name = "cloud-config"
      override = true
      template = ""      
    }
   }
  app_type = "APP_TYPE_VM" 
  deployment_type = "DEPLOYMENT_TYPE_STAND_ALONE"
  cpu_pinning_enabled = false
 }
  user_defined_version = "7.4.3"
  origin_type = "ORIGIN_LOCAL"
  project_access_list = [zedcloud_project.tf_toi_project_1.id]
}

############################# Create UBUNTU App ###############################################################################################
resource "zedcloud_application" "tf_edge_app_ubuntu" {
  name = "UBUNTU-24"
  title = "UBUNTU-24"
  description = "Ubuntu Test VM"
  cpus = 2
  memory = 2048576
  storage = 20971520
  manifest {
    ac_kind = "VMManifest"
    ac_version = "1.2.0"
    name = "UBUNTU-24"
    display_name = "UBUNTU-24"
    owner {
      user = "Manny"
      company = "Zededa"
      website = "www.zededa.com"
      email = "manny@zededa.com"
    }
  desc {
    app_category = "APP_CATEGORY_UNSPECIFIED"
    category = "APP_CATEGORY_OPERATING_SYSTEM"
   }
  images {
    imagename = zedcloud_image.tf_ubuntu_image.name
    imageid   = zedcloud_image.tf_ubuntu_image.id
    imageformat = "QCOW2"
    maxsize = "20971520"
    target = "Disk"
    drvtype = "HDD"
    readonly = false
    ignorepurge = false
    cleartext = false
   }
  interfaces {
    name = "eth0"
    type = ""
    directattach = false
    privateip = false
   acls {                                                                    ##### Equivalent of an outbound rule when creating an app Web UI
      matches {   
        type = "ip"
        value = "0.0.0.0/0"
      }
    }
    acls { 
      matches {                                                               ##### Equivalent of an inbound rule
        type = "ip"
        value = "0.0.0.0/0"
      }
      actions {
        portmap = true
        portmapto {
          app_port = 22                                                       ##### Map application port 22                                   
        }
      }
      matches {
        type = "protocol"               
        value = "tcp"                                                         ##### Matching TCP protocol
      }
      matches {
        type = "lport"
        value = 8322                                                          ##### External port mapping to internal app port on line 313 from outside EVE)
     }
      matches {
        type = "ip"
        value = "0.0.0.0/0"
     }
    }
   }
  vmmode = "HV_HVM"
  enablevnc = true
  resources {
    name = "resourceType"
    value = "Custom"
  }
  resources {
    name = "cpus"
    value = 2
  }
  resources {
    name = "memory"
    value = 2048576
  }
  resources {
    name = "storage"
    value = 20971520
  }
  configuration {
    custom_config {
      name = "cloud-config"
      add = true
      override = true
      allow_storage_resize = true
      field_delimiter = ""
    }
   }
  app_type = "APP_TYPE_VM"
  deployment_type = "DEPLOYMENT_TYPE_STAND_ALONE"
  cpu_pinning_enabled = false
  }
project_access_list = [zedcloud_project.tf_toi_project_1.id]
depends_on = [zedcloud_image.tf_ubuntu_image]
}

################################################################################################################################################
###################### EDGE NODE MANAGEMENT NETWORK ############################################################################################
resource "zedcloud_network" "tf_eve_net_1" {                              ##### Required before creating an edge node
 name = "TOI-EVE-NET"
 title = "TOI-EVE-NET"
 description = "TF simple IPv4 DHCP Client"
 enterprise_default = false
 kind = "NETWORK_KIND_V4"
 ip {
 dhcp = "NETWORK_DHCP_TYPE_CLIENT"                                         ###### EVE management port in DHCP mode
 }
    project_id = zedcloud_project.tf_toi_project_1.id

    depends_on = [ zedcloud_project.tf_toi_project_1 ]
}

################################################################################################################################################
############ Create the EDGE NODE
resource "zedcloud_edgenode" "tf_edgenode_create" {
  model_id = "e1f68b0b-5678-4473-9019-9ca878158d99"                                   ###### This is the model ID of the model created before onboarding
  name = "TOI-EDGE-NODE"
  title = "TOI-EDGE-NODE"
  project_id = zedcloud_project.tf_toi_project_1.id
  onboarding_key = "<zededa onboarding key>"                                          ###### Zededa onboarding key
  serialno = "soft_serial"                                                             ###### This can be soft_serial or physical serial depends on your situation
  description = "TOI Demo"
  admin_state = "ADMIN_STATE_ACTIVE"
  
    config_item {
        bool_value   = false
        float_value  = 0
        key          = "debug.enable.ssh"                                             
        string_value = "<public key>"                                                 ##### Add your public key to create the edge node w/ your key pre-configured
        uint32_value = 0
        uint64_value = 0
    }
    config_item {
        bool_value    = false
        float_value   = 0
        key           = "debug.disable.dhcp.all-ones.netmask"                         ##### Disabled DHCP assigning /32 ip addresses - some VNFs cannot handle /32 DHCP assignments
        value_type    = true
        uint32_value  = 0
        uint64_value  = 0
    }
    edgeviewconfig {
        generation_id = 0
        token         = "<session token>"                                             ##### Allows you to pre-configure your session token for Edge View

        app_policy {
            allow_app = true
        }

        dev_policy {
            allow_dev = true
        }

        ext_policy {
            allow_ext = true
        }

        jwt_info {
            allow_sec  = 18000
            disp_url   = "zedcloud.pmwtus.zededa.net/api/v1/edge-view"                ###### Enable Edge View on your edge node.
            encrypt    = true
            expire_sec = "0"
            num_inst   = 3
        }  
    }
    interfaces {                                                                      ##### The endge nodes interface layout - follow the spec.sh
        cost       = 0
        intf_usage = "ADAPTER_USAGE_APP_SHARED"
        intfname   = "USB"
        tags       = {}
    }
    interfaces {
        cost       = 0
        intf_usage = "ADAPTER_USAGE_APP_SHARED"
        intfname   = "COM1"
        tags       = {}
    }
    interfaces {
        cost       = 0
        intf_usage = "ADAPTER_USAGE_APP_SHARED"
        intfname   = "COM2"
        tags       = {}
    }
    interfaces {
        cost       = 0
        intf_usage = "ADAPTER_USAGE_APP_SHARED"
        intfname   = "COM3"
        tags       = {}
    }
    interfaces {
        cost       = 0
        intf_usage = "ADAPTER_USAGE_MANAGEMENT"                          ##### eth0 designated as management port
        intfname   = "eth0"
        netname    = zedcloud_network.tf_eve_net_1.name                  ##### Because I want eth0 to be my management port, I map it to the Network created on line 367
        tags       = {}
    }
    interfaces {
        cost       = 0
        intf_usage = "ADAPTER_USAGE_APP_SHARED"
        intfname   = "eth1"
        netname = ""
        tags       = {}
    }
    interfaces {
        cost       = 0
        intf_usage = "ADAPTER_USAGE_APP_SHARED"
        intfname   = "eth2"
        netname = ""
        tags       = {}
    }
    interfaces {
        cost       = 0
        intf_usage = "ADAPTER_USAGE_APP_SHARED"
        intfname   = "eth3"
        netname = ""
        tags       = {}
    }
    interfaces {
        cost       = 0
        intf_usage = "ADAPTER_USAGE_APP_SHARED"
        intfname   = "eth4"
        netname    = ""
        tags       = {}
    }
    interfaces {
        cost       = 0
        intf_usage = "ADAPTER_USAGE_APP_SHARED"
        intfname   = "eth5"
        netname    = ""
        tags       = {}
    }

    depends_on = [ 
        zedcloud_network.tf_eve_net_1 ]               ##### Here I create a dependency on this network. Just as an example, Zededa will not allow you to delete once used anyway
}

#################################################################################################################################################
########### Network Instances ######### #########################################################################################################
resource "zedcloud_network_instance" "tf_mgt_net_1" { 
  name = "MGT-NET"                                            ##### Creating a management Network Instance type switch, no DHCP, for Firewall Port1
  title = "MGT-NET"
  kind = "NETWORK_INSTANCE_KIND_SWITCH"                       ##### Instance type switch
  type = "NETWORK_INSTANCE_DHCP_TYPE_UNSPECIFIED"
  port = "eth1"                                               ##### Physical port eth2 is assigned to this Network Instance
  device_id = zedcloud_edgenode.tf_edgenode_create.id         ##### Denotes the edge node you want to create this Network Instance on - Edge created in line 383
  ip {
    dhcp_range {
    end = "10.1.0.30"
    start = "10.1.0.20"
    }
    dns = [
      "1.1.1.1"
    ]
    domain = ""
    gateway = "10.1.0.1"
    ntp = ""
    subnet = "10.1.0.0/24"
    }
}

resource "zedcloud_network_instance" "tf_untrust_net_1" {     ##### Another Network Instance for the firewall Port2
  name = "UNTRUST-NET"
  title = "UNTRUST-NET"
  kind = "NETWORK_INSTANCE_KIND_SWITCH"                       ##### Instance type switch
  type = "NETWORK_INSTANCE_DHCP_TYPE_V4"
  port = "eth4"                                               ##### Mapping to physical port eth4           
  device_id = zedcloud_edgenode.tf_edgenode_create.id         ##### Denotes the edge node you want to create this Network Instance on - Edge created in line 383
}

resource "zedcloud_network_instance" "tf_airgap_net_1" {
  name = "AIRGAP-NET"                                         ##### Creating an airgapped Network Instance for connectivity between two VMs
  title = "AIRGAP-NET"
  kind = "NETWORK_INSTANCE_KIND_LOCAL"
  type = "NETWORK_INSTANCE_DHCP_TYPE_V4"                      ##### Create an IPv4 DHCP enabled Network Instance (VMs will get an IP if configured for DHCP)
  port = ""
  device_id = zedcloud_edgenode.tf_edgenode_create.id         ##### Denotes the edge node you want to create this Network Instance on - Edge created in line 383
  ip {
  dhcp_range {
  end = "10.3.0.30"
  start = "10.3.0.20"
  }
  dns = [
    "1.1.1.1"
  ]
  domain = ""
  gateway = "10.3.0.1"
  ntp = ""
  subnet = "10.3.0.0/24"
  }
 depends_on = [ zedcloud_edgenode.tf_edgenode_create ]
}

resource "zedcloud_network_instance" "tf_wan_net_1" {
  name = "WAN-NET"
  title = "WAN-NET"
  kind = "NETWORK_INSTANCE_KIND_LOCAL"
  type = "NETWORK_INSTANCE_DHCP_TYPE_V4"
  port = "eth0"
  device_id = zedcloud_edgenode.tf_edgenode_create.id
  ip {
    dhcp_range {
    end = "10.2.0.30"
    start = "10.2.0.20"
  }
    dns = [
      "1.1.1.1"
  ]
    domain = ""
    gateway = "10.2.0.1"
    ntp = "64.246.132.14"
    subnet = "10.2.0.0/24"
  }
 depends_on = [ zedcloud_edgenode.tf_edgenode_create ]
}

#################################### Deploy FORTIGATE ##################################
resource "zedcloud_application_instance" "deploy_fortigate_2" {
  name              = "TOI-FORTIGATE-FW"
  title             = "TOI-FORTIGATE-FW"
  project_id        = zedcloud_project.tf_toi_project_1.id
  app_id            = zedcloud_application.tf_edge_app_fortigate_sw_eth0.id
  activate          = true
  custom_config {
    add             = true
    allow_storage_resize = true
    field_delimiter = ""
    name            = "cloud-config"
    override        = true
  }
  logs {
    access = true
  }
  device_id         = zedcloud_edgenode.tf_edgenode_create.id
  drives {
    imagename       = zedcloud_image.tf_fortigate_image.name ##### Points at the image created above in line 53
    maxsize         = 20971520
    preserve        = false
    target          = "Disk"
    drvtype         = "HDD"
    readonly        = false
  }
  drives {
    imagename       = zedcloud_image.tf_forti_lic_iso.name  ##### Points at the image created above in line 69
    maxsize         = 1097152
    preserve        = false
    target          = "Disk"
    drvtype         = "CDROM"
    readonly        = true
  }
  interfaces { ############ PORT 1 on Fortigate
    directattach = false 
    access_vlan_id = 0
    default_net_instance = false 
    intfname = "eth0"
    intforder = 1
    ipaddr = ""
    macaddr = "00:1a:2b:3c:4d:5f"
    netinstname = "MGT-NET"
    privateip = false
  }
  interfaces { ############ PORT 2 on Fortigate
    directattach = false 
    access_vlan_id = 0
    default_net_instance = false
    intfname = "eth1"
    intforder = 2
    ipaddr = ""
    macaddr = "00:1a:2b:3c:4d:ef"
    netinstname = "UNTRUST-NET"
    privateip = false   
  }
    interfaces { ############ PORT 3 on Fortigate
    directattach = false 
    access_vlan_id = 0
    default_net_instance = false
    intfname = "eth2"
    intforder = 3
    ipaddr = "10.2.0.11"
    macaddr = ""
    netinstname = "AIRGAP-NET"
    privateip = false   
  }
}

####################################### Deploy Linux instance###########################################
resource "zedcloud_application_instance" "deploy_linux_node_1" {
  count             = length(var.virtual_machine_name)                ##### I want to create more than one instance and base the # of instances based on 'variables.tf' entries
  name              = var.virtual_machine_name[count.index]           ##### Names also created based on variables.tf entries 
  title             = var.virtual_machine_name[count.index]           ##### same for title
  project_id        = zedcloud_project.tf_toi_project_1.id
  app_id            = zedcloud_application.tf_edge_app_ubuntu.id    ##### Points at the image created above in line 101
  activate          = true
  custom_config {
    add             = true
    allow_storage_resize = true
    field_delimiter = "###"
    name            = "cloud-config"
    override        = true
    template        = base64encode(file(var.cinit_name[count.index])) ##### Since each VM has a different config, I point each VMs to their specific cloud-init file
  }
  device_id         = zedcloud_edgenode.tf_edgenode_create.id
  drives {
    imagename       = zedcloud_image.tf_ubuntu_image.name
    cleartext       = false
    ignorepurge     = true
    maxsize         = 20971520
    preserve        = false
    target          = "Disk"
    drvtype         = "HDD"
    readonly        = false
  }
  interfaces {
    intfname = "eth0"
    directattach = false
    access_vlan_id = 0
    default_net_instance = false
    ipaddr = ""
    macaddr = ""
    netinstname = "MGT-NET"
    privateip = false
  }
  interfaces {
    intfname = "eth1"
    directattach = false
    access_vlan_id = 0
    default_net_instance = false
    ipaddr = ""
    macaddr = ""
    netinstname = var.network_instance_name[count.index]        ##### I assign the different Network Instance also based on the 'variables.tf' entries
    privateip = false
  }
}
