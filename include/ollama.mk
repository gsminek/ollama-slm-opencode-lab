# include/ollama.mk

OLLAMA					?= ollama
OLLAMA_USERNAME			?= $(USERNAME)

MODEL_BASEDIR			?= $(realpath ..)
MODEL_NAME				?= $(shell basename $(MODEL_BASEDIR))
MODEL_TAG				?= latest

BASE_MODEL_NAME			?= $(MODEL_NAME)-$(MODEL_TAG)

FAST_MODEL_NAME			?= $(BASE_MODEL_NAME)-fast
FAST_MODEL_CTX_LEN		?= 16384

AGENT_MODEL_NAME		?= $(BASE_MODEL_NAME)-agent
AGENT_MODEL_CTX_LEN		?= 65536

.PHONY: ollama.show
ollama.show:
	@echo "Model Base dir:      $(MODEL_BASEDIR)"
	@echo "Model Name:          $(MODEL_NAME):$(MODEL_TAG)"
	@echo "Fast Model Name:     $(FAST_MODEL_NAME)"
	@echo "Agent Model Name:    $(AGENT_MODEL_NAME)"
	ollama ls | grep $(MODEL_NAME)

$(BASE_MODEL_NAME).Modelfile:
	$(OLLAMA) show $(MODEL_NAME):$(MODEL_TAG) --modelfile \
	| sed '1,3d' \
	| sed -E "/^FROM /d" \
	| sed -E "1i FROM $(MODEL_NAME):$(MODEL_TAG)" \
	> $@

$(FAST_MODEL_NAME).model:
	mkdir $@

$(FAST_MODEL_NAME).model/$(FAST_MODEL_NAME).Modelfile: $(BASE_MODEL_NAME).Modelfile $(FAST_MODEL_NAME).model
	{ \
	cat $< | grep -v "PARAMETER num_ctx"; \
	echo "PARAMETER num_ctx $(FAST_MODEL_CTX_LEN)"; \
	} > $@

.PHONY: $(OLLAMA_USERNAME)/$(FAST_MODEL_NAME)
$(OLLAMA_USERNAME)/$(FAST_MODEL_NAME): $(FAST_MODEL_NAME).model/$(FAST_MODEL_NAME).Modelfile
	-ollama stop $@
	ollama create $@ -f $<

$(AGENT_MODEL_NAME).model:
	mkdir $@

$(AGENT_MODEL_NAME).model/$(AGENT_MODEL_NAME).Modelfile: $(BASE_MODEL_NAME).Modelfile $(AGENT_MODEL_NAME).model
	{ \
	cat $< | grep -v "PARAMETER num_ctx"; \
	echo "PARAMETER num_ctx $(AGENT_MODEL_CTX_LEN)"; \
	} > $@

.PHONY: $(OLLAMA_USERNAME)/$(AGENT_MODEL_NAME)
$(OLLAMA_USERNAME)/$(AGENT_MODEL_NAME): $(AGENT_MODEL_NAME).model/$(AGENT_MODEL_NAME).Modelfile
	-ollama stop $@
	ollama create $@ -f $<

.PHONY: ollama.init
ollama.init: \
	$(FAST_MODEL_NAME).model/$(FAST_MODEL_NAME).Modelfile \
	$(AGENT_MODEL_NAME).model/$(AGENT_MODEL_NAME).Modelfile

.PHONY: ollama.create
ollama.create: $(OLLAMA_USERNAME)/$(FAST_MODEL_NAME) $(OLLAMA_USERNAME)/$(AGENT_MODEL_NAME)
	ollama ls | grep $(MODEL_NAME)

.PHONY: ollama.clean
ollama.clean:
	-rm -Rf $(FAST_MODEL_NAME).model
	-rm -Rf $(AGENT_MODEL_NAME).model

.PHONY: ollama.recreate
ollama.recreate: ollama.clean ollama.create

.PHONY: ollama.mostlyclean
ollama.mostlyclean: ollama.clean
	-ollama rm $(OLLAMA_USERNAME)/$(FAST_MODEL_NAME)
	-ollama rm $(OLLAMA_USERNAME)/$(AGENT_MODEL_NAME)

.PHONY: ollama.realclean
ollama.realclean: ollama.modtlyclean
	-rm $(BASE_MODEL_NAME).Modelfile

.PHONY: code.opencode
code.opencode:
	code $(USERPROFILE)/.config/opencode/opencode.json

.PHONY: opencode.launch
opencode.launch:
	ollama launch opencode --model $(AGENT_MODEL_NAME)
