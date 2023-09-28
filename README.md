# Gentoo Installer

This Bash script simplifies the process of installing Gentoo, providing an easy and efficient way to set up your Gentoo system. It automates various installation steps, making the process straightforward and user-friendly.

## Installation

To install Gentoo using this script, follow these steps:

1. Clone this repository to your local machine:

   ```bash
   git clone https://github.com/tylerapohl/gentoo-installer.git
   ```

2. Navigate to the project directory:

   ```bash
   cd gentoo-installer
   ```

3. Run the installer script with your desired configuration. Here are some available options:

   - **Custom Stage3 Tarball**: Use the `-s` or `--stage3` option to specify a custom Stage3 tarball.

   - **Custom Package Use Flags**: Use the `-f` or `--flags` option to specify custom package.use flags.

   - **Custom Package Set**: Use the `-p` or `--packageset` option to specify a custom package set.

   - **Binary Package Host**: Use the `-b` or `--binpkgs` option to specify the binpkg host.

   - **Repository URL**: Use the `-r` or `--repo` option to specify a repository URL.

   - **Portage Tree Snapshot**: Use the `-t` or `--portagetree` option to specify a custom portage tree snapshot (*.tar.bz2).

   - **Verbose Mode**: Use the `-v` or `--verbose` option to enable verbose mode for more detailed output.

   - **Help Message**: Use the `-h` or `--help` option to display this help message.

## Usage

Here's an example of how to use this script:

```bash
sh gentoo-installer.sh -s stage3-amd64-desktop-openrc-20230917T164636Z.tar.xz -f use/custom-portage-2023-09-24 -p sets/fullset -b localhost -t portage-2023-09-24.tar.bz2
```

This command will initiate the Gentoo installation process with the specified options. You can customize the installation to fit your requirements.

## Note

- You may need to create the `chroot_use` manually, especially when setting up a new Stage3 installation.

This script streamlines the installation process, making it more accessible and user-friendly. Enjoy your Gentoo experience!
