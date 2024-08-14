variable "virtual_machine_name" {
    type    = list(string)
    default = [ "vm1","vm2" ]
}

variable "network_instance_name" {
    type    = list(string)
    default = [ 
        "TRUST-AIRGAP", 
        "UNTRUST-AIRGAP" ]
}

variable "cinit_name" {
    type    = list(string)
    default = [ 
        "./c-init/ubuntu-cloud-init-1.txt",
        "./c-init/ubuntu-cloud-init-2.txt" ]
}