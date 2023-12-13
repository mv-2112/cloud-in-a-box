#!/usr/bin/env bash

# Designate
sunbeam enable dns "ns1.example.com. ns2.example.com."

# Heat
sunbeam enable orchestration

# Grafana
# sunbeam enable observability

# Aodh/Gnocchi/Ceilometer
sunbeam enable telemetry
# juju integrate gnocchi microceph

# Vault
# sunbeam enable vault

# Octavia
sunbeam enable loadbalancer

# Magnum
sunbeam enable caas
sunbeam configure caas
# curl https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/38.20230806.3.0/x86_64/fedora-coreos-38.20230806.3.0-openstack.x86_64.qcow2.xz
