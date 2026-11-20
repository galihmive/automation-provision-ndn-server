#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  network:
    network:
      version: 2
      ethernets:
        all-en-interfaces:
          match:
            name: "en*"
          dhcp4: true
        all-eth-interfaces:
          match:
            name: "eth*"
          dhcp4: true
  identity:
    hostname: ubuntu24-desktop
    username: ubuntu
    password: "${password_hash}"
  ssh:
    install-server: true
    allow-pw: true
  packages:
    - virtualbox-guest-utils
    - virtualbox-guest-x11
    - curl
    - wget
    - git
    - sudo
  storage:
    layout:
      name: direct
  user-data:
    package_update: true
    package_upgrade: false
    disable_root: false
  late-commands:
    - echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/ubuntu
    - chmod 440 /target/etc/sudoers.d/ubuntu
