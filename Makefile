# Copyright 2024 Patrick Deglon
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

APP := tidbyt_cloud_status
STAR := $(APP).star
WEBP := $(APP).webp

.PHONY: default render serve push clean

# Minimal conveniences; primary flow is ./refresh.sh
default: push

render:
	pixlet render $(STAR)

serve:
	pixlet serve $(STAR)

push: render
	./refresh.sh

clean:
	rm -f $(WEBP)

# Serve the Tidbyt app locally for development and preview
serve:
	@pixlet serve $(STAR) $(ARGS)

# Show code of all files in the project
showcode:
	@{ \
		for f in `git ls-files` ; do \
			echo "// $$f"; \
			cat "$$f"; \
			echo; \
			echo "----------------------------------------------"; \
			echo; \
		done; \
	} | xclip -selection clipboard
	@echo "All code copied to clipboard"

# Clean up any generated files
clean:
	@rm -f $(WEBP)
