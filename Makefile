nix-build-attr = nix-build --no-out-link jobsets/release.nix -A $(1)

nix-build-tests = nix-build --no-out-link jobsets/release-tests.nix

test:
	$(call nix-build-tests)

help:
	@echo "Targets:"
	@echo
	@echo "(Default is 'tests')"
	@echo
	@echo "    test      - build all tests"
	@echo
	@echo "General:"
	@echo
	@echo "    help  - show this message"

.PHONY: test
