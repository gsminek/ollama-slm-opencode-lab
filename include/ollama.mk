# include/ollama.mk

OLLAMA					?= ollama
OLLAMA_USERNAME			?= $(USERNAME)
OLLAMA_HOST				?= localhost:11434

MODEL_BASEDIR			?= $(realpath ..)
MODEL_NAME				?= $(shell basename $(MODEL_BASEDIR))
MODEL_TAG				?= latest

BASE_MODEL_NAME			?= $(MODEL_NAME)-$(MODEL_TAG)

FAST_MODEL_NAME			?= $(BASE_MODEL_NAME)-fast
FAST_MODEL_CTX_LEN		?= 16384

AGENT_MODEL_NAME		?= $(BASE_MODEL_NAME)-agent
AGENT_MODEL_CTX_LEN		?= 65536

TEST_TOOL_PROMPT ?= \
{ \
  "model": "$(OLLAMA_USERNAME)/$(AGENT_MODEL_NAME)", \
  "messages": [{"role": "user", "content": "ls the directory"}], \
  "stream": false \
}

.PHONY: ollama.show
ollama.show:
	@echo "Model Base dir:      $(MODEL_BASEDIR)"
	@echo "Model Name:          $(MODEL_NAME):$(MODEL_TAG)"
	@echo "Fast Model Name:     $(FAST_MODEL_NAME)"
	@echo "Agent Model Name:    $(AGENT_MODEL_NAME)"
	ollama ls | grep $(MODEL_NAME)

.PHONY: ollama.pull
ollama.pull:
	ollama pull $(MODEL_NAME):$(MODEL_TAG)

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

.PHONY: opencode.launch-fast
opencode.launch-fast:
	ollama launch opencode --model $(OLLAMA_USERNAME)/$(FAST_MODEL_NAME)

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

.PHONY: opencode.launch-agent
opencode.launch-agent:
	ollama launch opencode --model $(OLLAMA_USERNAME)/$(AGENT_MODEL_NAME)

.PHONY: test.tool-agent
test.tool-agent:
	curl http://$(OLLAMA_HOST)/api/chat -d '$(TEST_TOOL_PROMPT)'

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

.PHONY: ollama.stop
ollama.stop:
	-ollama stop $(MODEL_NAME):$(MODEL_TAG)
	-ollama stop $(OLLAMA_USERNAME)/$(FAST_MODEL_NAME)
	-ollama stop $(OLLAMA_USERNAME)/$(AGENT_MODEL_NAME)
	@ollama ps | grep $(MODEL_NAME)

.PHONY: ollama.mostlyclean
ollama.mostlyclean: ollama.stop ollama.clean
	-ollama rm $(OLLAMA_USERNAME)/$(FAST_MODEL_NAME)
	-ollama rm $(OLLAMA_USERNAME)/$(AGENT_MODEL_NAME)

.PHONY: ollama.realclean
ollama.realclean: ollama.modtlyclean
	-rm $(BASE_MODEL_NAME).Modelfile

.PHONY: code.opencode
code.opencode:
	code $(USERPROFILE)/.config/opencode/opencode.json

.PHONY: launch.opencode
launch.opencode:
	ollama launch opencode --model $(MODEL_NAME):$(MODEL_TAG)
