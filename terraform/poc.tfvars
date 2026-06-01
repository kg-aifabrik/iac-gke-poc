project_id      = "k8s-iac-poc"
region          = "us-central1"
zones           = ["us-central1-a", "us-central1-b", "us-central1-c"]
cluster_name    = "poc"
authorized_ipv4 = "108.221.21.223/32" # operator IP; update if it changes
release_channel = "REGULAR"
