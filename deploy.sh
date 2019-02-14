#!/bin/bash

set -o errexit -o nounset

terraform init

terraform plan

terraform apply
