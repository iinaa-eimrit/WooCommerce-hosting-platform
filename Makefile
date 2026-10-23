CLUSTER := urumi
ENV ?= local
TAG := $(shell date +%Y%m%d%H%M%S)
IMAGES := woo-mcp utils-mcp everything-mcp gateway dashboard
cluster:
	k3d cluster create $(CLUSTER) --servers 1 --agents 0 -p "80:80@loadbalancer" -p "443:443@loadbalancer"
images:
	@for image in $(IMAGES); do docker build -t urumi/$$image:$(TAG) services/$$image || exit 1; done
	k3d image import $(addprefix urumi/,$(addsuffix :$(TAG),$(IMAGES))) -c $(CLUSTER)
secrets:
	./scripts/gen-secrets.sh $(ENV)
deploy:
	helm upgrade --install store charts/store -n store --create-namespace -f charts/store/values-$(ENV).yaml --set wooMcp.image.tag=$(TAG) --wait --wait-for-jobs --timeout 15m
	helm upgrade --install utils charts/mcp-server -n mcp-upstreams --create-namespace -f charts/mcp-server/values-utils.yaml --set image.tag=$(TAG) --wait
	helm upgrade --install everything charts/mcp-server -n mcp-upstreams -f charts/mcp-server/values-everything.yaml --set image.tag=$(TAG) --wait
	helm upgrade --install gateway charts/gateway -n gateway --create-namespace -f charts/gateway/values-$(ENV).yaml --set backend.image.tag=$(TAG) --set dashboard.image.tag=$(TAG) --wait
up: images secrets deploy
down:
	k3d cluster delete $(CLUSTER)
