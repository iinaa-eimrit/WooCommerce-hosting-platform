CLUSTER := urumi
ENV ?= local
TAG := $(shell date +%Y%m%d%H%M%S)
REGISTRY ?= urumi
PLATFORMS ?= linux/amd64,linux/arm64
IMAGES := woo-mcp utils-mcp everything-mcp gateway dashboard
cluster:
	k3d cluster create $(CLUSTER) --servers 1 --agents 0 -p "80:80@loadbalancer" -p "443:443@loadbalancer"
images:
	@for image in $(IMAGES); do docker build -t urumi/$$image:$(TAG) services/$$image || exit 1; done
	k3d image import $(addprefix urumi/,$(addsuffix :$(TAG),$(IMAGES))) -c $(CLUSTER)
publish:
	@test "$(REGISTRY)" != urumi || (echo 'Set REGISTRY to your container registry namespace' >&2; exit 1)
	@for image in $(IMAGES); do docker buildx build --platform $(PLATFORMS) -t $(REGISTRY)/$$image:$(TAG) --push services/$$image || exit 1; done
secrets:
	./scripts/gen-secrets.sh $(ENV)
deploy:
	helm upgrade --install store charts/store -n store --create-namespace -f charts/store/values-$(ENV).yaml --set wooMcp.image.repository=$(REGISTRY)/woo-mcp --set wooMcp.image.tag=$(TAG) $(if $(STORE_HOST),--set ingress.host=$(STORE_HOST) --set siteUrl=https://$(STORE_HOST)) --wait --wait-for-jobs --timeout 15m
	helm upgrade --install utils charts/mcp-server -n mcp-upstreams --create-namespace -f charts/mcp-server/values-utils.yaml --set image.repository=$(REGISTRY)/utils-mcp --set image.tag=$(TAG) --wait
	helm upgrade --install everything charts/mcp-server -n mcp-upstreams -f charts/mcp-server/values-everything.yaml --set image.repository=$(REGISTRY)/everything-mcp --set image.tag=$(TAG) --wait
	helm upgrade --install gateway charts/gateway -n gateway --create-namespace -f charts/gateway/values-$(ENV).yaml --set backend.image.repository=$(REGISTRY)/gateway --set backend.image.tag=$(TAG) --set dashboard.image.repository=$(REGISTRY)/dashboard --set dashboard.image.tag=$(TAG) $(if $(GATEWAY_HOST),--set host=$(GATEWAY_HOST)) --wait
up: images secrets deploy
down:
	k3d cluster delete $(CLUSTER)
