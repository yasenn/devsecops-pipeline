cat <<EOF > /home/$USER/.terraformrc
provider_installation {
  network_mirror {
    url     = "https://nm.tf.org.ru/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
EOF
    
cat <<EOF > /home/$USER/.tofurc
provider_installation {
  network_mirror {
    url = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.opentofu.org/*/*"]
  }
  direct {
    exclude = ["registry.opentofu.org/*/*"]
  }
}
EOF
