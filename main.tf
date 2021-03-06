data "openstack_compute_flavor_v2" "this" {
  name = "${var.flavor_name}"
}

data "openstack_images_image_v2" "this" {
  name        = "${var.image_name}"
  most_recent = true
}

resource "openstack_networking_secgroup_v2" "this" {
  count = "${var.security_group_name != "" ? 1 : 0}"

  name        = "${var.security_group_name}"
  description = "${format("%s %s", var.security_group_name, "security group")}"
}

resource "openstack_networking_secgroup_rule_v2" "this" {
  count = "${length(var.security_group_rules)}"

  port_range_min    = "${lookup(var.security_group_rules[count.index], "port_range_min")}"
  port_range_max    = "${lookup(var.security_group_rules[count.index], "port_range_max")}"
  protocol          = "${lookup(var.security_group_rules[count.index], "protocol")}"
  direction         = "${lookup(var.security_group_rules[count.index], "direction")}"
  ethertype         = "${lookup(var.security_group_rules[count.index], "ethertype")}"
  remote_ip_prefix  = "${lookup(var.security_group_rules[count.index], "remote_ip_prefix")}"
  security_group_id = "${element(openstack_networking_secgroup_v2.this.*.id, count.index)}"
}

# This trigger wait for subnet defined outside of this module to be created
resource "null_resource" "network_subnet_found" {
  count = "${length(var.subnet_ids)}"

  triggers = {
    subnet = "${var.subnet_ids[count.index][0]}"
  }
}

resource "openstack_compute_instance_v2" "this" {
  count = "${var.instance_count}"

  depends_on = ["null_resource.network_subnet_found"]

  name            = "${var.instance_count > 1 ? format("%s-%s", var.instance_name, count.index) : var.instance_name}"
  image_name      = "${data.openstack_images_image_v2.this.name}"
  flavor_id       = "${data.openstack_compute_flavor_v2.this.id}"
  key_pair        = "${var.keypair}"
  security_groups = "${openstack_networking_secgroup_v2.this.*.name}"

  dynamic "network" {
    for_each = var.network_ids

    content {
      uuid = network.value
    }
  }
}

# resource "openstack_compute_interface_attach_v2" "this" {
#   count = "${var.instance_count}"


#   instance_id = "${openstack_compute_instance_v2.this.*.id[count.index]}"
#   network_id     = "${var.network_id}"
# }
