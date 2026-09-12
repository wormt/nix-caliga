VM_NAME       := "ghcr.io/nix-caliga/nix-caliga:fedora-bootc"
PODMAN_SOCKET := "unix:///run/user/6969/podman/podman.sock"
PODMAN        := "podman --remote --url unix:///run/user/6969/podman/podman.sock"
BCVK          := "distrobox-host-exec bash -lc 'export PATH=/var/home/asv/.local/bin:$PATH; cd /var/home/asv/workspaces/roc/blog2 && bcvk"

podman *args:
	{{PODMAN}} {{args}}

podman-images:
	{{PODMAN}} images

podman-ps:
	{{PODMAN}} ps

podman-load *args:
	{{PODMAN}} load -i {{args}}

build:
	nix build .#caligaConfigurations.x86_64-linux.fedora-bootc.config.build.image
	./result > image.tar
	@echo "image built at ./image.tar"

load: 
	{{PODMAN}} load -i image.tar

vm:
	-distrobox-host-exec podman --remote --url '{{ PODMAN_SOCKET }}' rm -f caliga_dev_bcvk
	{{BCVK}} ephemeral run '{{ VM_NAME }}' --rm --name=caliga_dev_bcvk --detach --ssh-keygen --console'

vm-ssh *args:
	{{BCVK}} ephemeral ssh caliga_dev_bcvk "$@"' _ {{quote(args)}}

rebuild: build load vm
	@echo "image rebuilt, loaded into podman, started with bcvk"
