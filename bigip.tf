# BIG-IP

# Public IP for VIP
resource "google_compute_address" "vip1" {
  name = "${var.prefix}-vip1"
}

# Forwarding rule for Public IP
resource "google_compute_forwarding_rule" "vip1" {
  name       = "${var.prefix}-forwarding-rule"
  target     = google_compute_target_instance.f5vm02.id
  ip_address = google_compute_address.vip1.address
  port_range = "1-65535"
}

resource "google_compute_target_instance" "f5vm01" {
  name     = "${var.prefix}-${var.bigipHost1Name}-ti"
  instance = google_compute_instance.f5vm01.id
}

resource "google_compute_target_instance" "f5vm02" {
  name     = "${var.prefix}-${var.bigipHost2Name}-ti"
  instance = google_compute_instance.f5vm02.id
}
# bucket
resource google_storage_bucket bigip-ha {
  name     = "${var.prefix}-bigip-storage"
  location = "US"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
  labels = {
    f5_cloud_failover_label = var.bigipCloudFailoverLabel
  }
  force_destroy = true
}
# Setup Onboarding scripts
# #do_byol.json, do.json, do_bigiq.json
# Setup Onboarding scripts
locals {
  vm01_onboard = templatefile("${path.module}/templates/bigip/startup.sh.tpl", {
    bigipUsername            = var.bigipUsername
    bigipSecret              = var.bigipSecret
    serviceAccountSecretName = var.serviceAccountSecretName
    bigIqSecret              = var.bigIqSecret != "" ? var.bigIqSecret : ""
    gcp_project_id           = var.gcpProjectId
    doUrl                    = var.doUrl
    as3Url                   = var.as3Url
    tsUrl                    = var.tsUrl
    cfUrl                    = var.cfUrl
    bigipOnboardLog          = var.bigipOnboardLog
    DO_Document              = local.vm01_do_json
    AS3_Document             = ""
    TS_Document              = local.ts_json
    CFE_Document             = local.vm01_cfe_json
    prefix                   = var.prefix
    podCidr                  = google_container_cluster.primary.ip_allocation_policy.0.cluster_ipv4_cidr_block
  })
  vm02_onboard = templatefile("${path.module}/templates/bigip/startup.sh.tpl", {
    bigipUsername            = var.bigipUsername
    bigipSecret              = var.bigipSecret
    serviceAccountSecretName = var.serviceAccountSecretName
    bigIqSecret              = var.bigIqSecret != "" ? var.bigIqSecret : ""
    gcp_project_id           = var.gcpProjectId
    doUrl                    = var.doUrl
    as3Url                   = var.as3Url
    tsUrl                    = var.tsUrl
    cfUrl                    = var.cfUrl
    bigipOnboardLog          = var.bigipOnboardLog
    DO_Document              = local.vm02_do_json
    AS3_Document             = local.as3_json
    TS_Document              = local.ts_json
    CFE_Document             = local.vm02_cfe_json
    prefix                   = var.prefix
    podCidr                  = google_container_cluster.primary.ip_allocation_policy.0.cluster_ipv4_cidr_block
  })
  vm01_do_json = templatefile("${"${"${path.module}/templates/bigip/do"}${var.license1 != "" ? "_byol" : "${var.bigIqLicensePool != "" ? "_bigiq" : ""}"}"}${var.bigIqUnitOfMeasure != "" ? "_ela" : ""}.json.tpl", {
    regKey             = var.license1
    admin_username     = var.bigipUsername
    host1              = "${var.prefix}-${var.bigipHost1Name}"
    host2              = "${var.prefix}-${var.bigipHost2Name}"
    remote_host        = "${var.prefix}-${var.bigipHost2Name}"
    dnsServer          = var.dnsServer
    dnsSuffix          = var.dnsSuffix
    ntpServer          = var.ntpServer
    timezone           = var.timezone
    bigIqLicenseType   = var.bigIqLicenseType
    bigIqHost          = var.bigIqHost
    bigIqUsername      = var.bigIqUsername
    bigIqLicensePool   = var.bigIqLicensePool
    bigIqSkuKeyword1   = var.bigIqSkuKeyword1
    bigIqSkuKeyword2   = var.bigIqSkuKeyword2
    bigIqUnitOfMeasure = var.bigIqUnitOfMeasure
    bigIqHypervisor    = var.bigIqHypervisor
  })
  vm02_do_json = templatefile("${"${"${path.module}/templates/bigip/do"}${var.license2 != "" ? "_byol" : "${var.bigIqLicensePool != "" ? "_bigiq" : ""}"}"}${var.bigIqUnitOfMeasure != "" ? "_ela" : ""}.json.tpl", {
    regKey             = var.license2
    admin_username     = var.bigipUsername
    host1              = "${var.prefix}-${var.bigipHost1Name}"
    host2              = "${var.prefix}-${var.bigipHost2Name}"
    remote_host        = google_compute_instance.f5vm01.network_interface.1.network_ip
    dnsServer          = var.dnsServer
    dnsSuffix          = var.dnsSuffix
    ntpServer          = var.ntpServer
    timezone           = var.timezone
    bigIqLicenseType   = var.bigIqLicenseType
    bigIqHost          = var.bigIqHost
    bigIqUsername      = var.bigIqUsername
    bigIqLicensePool   = var.bigIqLicensePool
    bigIqSkuKeyword1   = var.bigIqSkuKeyword1
    bigIqSkuKeyword2   = var.bigIqSkuKeyword2
    bigIqUnitOfMeasure = var.bigIqUnitOfMeasure
    bigIqHypervisor    = var.bigIqHypervisor
  })
  as3_json = templatefile("${path.module}/templates/bigip/as3.json.tpl", {
    gcp_region = var.gcpRegion
    #publicvip  = "0.0.0.0"
    publicvip     = google_compute_address.vip1.address
    privatevip    = var.aliasIpRange
    uuid          = uuid()
    consulAddress = "1.2.3.4"
  })
  ts_json = templatefile("${path.module}/templates/bigip/ts.json.tpl", {
    gcp_project_id = var.gcpProjectId
    serviceAccount = var.serviceAccount
    privateKeyId   = var.privateKeyId
  })
  vm01_cfe_json = templatefile("${path.module}/templates/bigip/cfe.json.tpl", {
    bigipCloudFailoverLabel = var.bigipCloudFailoverLabel
    managedRoute1           = var.managedRoute1
    remote_selfip           = ""
  })
  vm02_cfe_json = templatefile("${path.module}/templates/bigip/cfe.json.tpl", {
    bigipCloudFailoverLabel = var.bigipCloudFailoverLabel
    managedRoute1           = var.managedRoute1
    remote_selfip           = google_compute_instance.f5vm01.network_interface.0.network_ip
  })
  vscode_f5_devices = templatefile("${path.module}/templates/bigip/.vscode-f5.json.tpl", {
    user          = var.bigipUsername
    device1       = google_compute_instance.f5vm01.network_interface.1.access_config.0.nat_ip
    device2       = google_compute_instance.f5vm02.network_interface.1.access_config.0.nat_ip
    logonProvider = "local"
    port          = "443"
  })
}
# Create F5 BIG-IP VMs
resource google_compute_instance f5vm01 {
  depends_on     = [google_container_cluster.primary, google_compute_subnetwork.vpc_network_mgmt_sub, google_compute_subnetwork.vpc_network_int_sub, google_compute_subnetwork.vpc_network_ext_sub]
  name           = "${var.prefix}-${var.bigipHost1Name}"
  machine_type   = var.bigipMachineType
  zone           = "${var.gcpRegion}-b"
  can_ip_forward = true

  labels = {
    f5_cloud_failover_label = var.bigipCloudFailoverLabel
  }

  tags = ["appfw-${var.prefix}", "mgmtfw-${var.prefix}"]

  boot_disk {
    initialize_params {
      image = var.bigipCustomImageName != "" ? var.bigipCustomImageName : var.bigipImageName
      size  = "128"
    }
  }

  network_interface {
    network    = var.extVpc
    subnetwork = var.extSubnet
    access_config {
    }
  }

  network_interface {
    network    = var.mgmtVpc
    subnetwork = var.mgmtSubnet
    access_config {
    }
  }

  network_interface {
    network    = var.intVpc
    subnetwork = var.intSubnet
    alias_ip_range {
      ip_cidr_range         = cidrsubnet(google_container_cluster.primary.ip_allocation_policy.0.cluster_ipv4_cidr_block, 10, 201)
      subnetwork_range_name = google_container_cluster.primary.ip_allocation_policy.0.cluster_secondary_range_name
    }
  }

  metadata = {
    ssh-keys               = "${var.bigipUsername}:${var.gceSshPublicKey}"
    block-project-ssh-keys = true
    startup-script         = var.bigipCustomImageName != "" ? var.customUserData : local.vm01_onboard
  }

  service_account {
    email  = google_service_account.gce-bigip-sa.email
    scopes = ["cloud-platform"]
  }
}

resource google_compute_instance f5vm02 {
  depends_on     = [google_container_cluster.primary, google_compute_subnetwork.vpc_network_mgmt_sub, google_compute_subnetwork.vpc_network_int_sub, google_compute_subnetwork.vpc_network_ext_sub]
  name           = "${var.prefix}-${var.bigipHost2Name}"
  machine_type   = var.bigipMachineType
  zone           = "${var.gcpRegion}-b"
  can_ip_forward = true

  labels = {
    f5_cloud_failover_label = var.bigipCloudFailoverLabel
  }

  tags = ["appfw-${var.prefix}", "mgmtfw-${var.prefix}"]

  boot_disk {
    initialize_params {
      image = var.bigipCustomImageName != "" ? var.bigipCustomImageName : var.bigipImageName
      size  = "128"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network_ext.name
    subnetwork = google_compute_subnetwork.vpc_network_ext_sub.name
    access_config {
    }
    alias_ip_range {
      ip_cidr_range = var.aliasIpRange
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network_mgmt.name
    subnetwork = google_compute_subnetwork.vpc_network_mgmt_sub.name
    access_config {
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network_int.name
    subnetwork = google_compute_subnetwork.vpc_network_int_sub.name
    alias_ip_range {
      ip_cidr_range         = cidrsubnet(google_container_cluster.primary.ip_allocation_policy.0.cluster_ipv4_cidr_block, 10, 202)
      subnetwork_range_name = google_container_cluster.primary.ip_allocation_policy.0.cluster_secondary_range_name
    }
  }

  metadata = {
    ssh-keys               = "${var.bigipUsername}:${var.gceSshPublicKey}"
    block-project-ssh-keys = true
    startup-script         = var.bigipCustomImageName != "" ? var.customUserData : local.vm02_onboard
  }

  service_account {
    email  = google_service_account.gce-bigip-sa.email
    scopes = ["cloud-platform"]
  }
}

# Troubleshooting - create local output files
#resource "local_file" "onboard_file" {
#  content  = local.vm01_onboard
#  filename = "${path.module}/vm01_onboard.sh"
#}
#resource "local_file" "do_file" {
#  content  = local.vm01_do_json
#  filename = "${path.module}/vm01_do.json"
#}

#https://f5devcentral.github.io/vscode-f5/#/device_importing?id=importing-devices
#/home/SomeUser/.vscode-server/extensions/devcentral.vscode-f5-v3.0.0/
resource "local_file" "f5_plugin_devices" {
  content  = local.vscode_f5_devices
  filename = "${path.module}/.vscode-f5.json"
}
