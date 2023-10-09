#!/usr/bin/env bash

# Designate
sunbeam enable dns "ns1.example.com. ns2.example.com."

# Heat
sunbeam enable orchestration

# Grafana
# sunbeam enable observability

# Aodh/Gnocchi/Ceilometer
sunbeam enable telemetry
juju integrate gnocchi microceph

# Vault
sunbeam enable vault

# Octavia
sunbeam enable loadbalancer
