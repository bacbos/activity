SHELL := /bin/bash

#
# Define NPM and check if it is available on the system.
#
NPM := $(shell command -v npm 2> /dev/null)
ifndef NPM
    $(error npm is not available on your system, please install npm)
endif

NODE_PREFIX=$(shell pwd)

PHPUNIT="$(PWD)/lib/composer/phpunit/phpunit/phpunit"
BOWER=$(NODE_PREFIX)/node_modules/bower/bin/bower
JSDOC=$(NODE_PREFIX)/node_modules/.bin/jsdoc

app_name=$(notdir $(CURDIR))
doc_files=README.md CHANGELOG.md CONTRIBUTING.md
src_dirs=appinfo css img js l10n lib templates
all_src=$(src_dirs) $(doc_files)
build_dir=$(CURDIR)/build
dist_dir=$(build_dir)/dist

# dependency folders (leave empty if not required)
nodejs_deps=
bower_deps=

# composer
composer_deps=vendor
composer_dev_deps=vendor/php-cs-fixer
COMPOSER_BIN=$(build_dir)/composer.phar

occ=$(CURDIR)/../../occ
private_key=$(HOME)/.owncloud/certificates/$(app_name).key
certificate=$(HOME)/.owncloud/certificates/$(app_name).crt
sign=$(occ) integrity:sign-app --privateKey="$(private_key)" --certificate="$(certificate)"
sign_skip_msg="Skipping signing, either no key and certificate found in $(private_key) and $(certificate) or occ can not be found at $(occ)"
ifneq (,$(wildcard $(private_key)))
ifneq (,$(wildcard $(certificate)))
ifneq (,$(wildcard $(occ)))
	CAN_SIGN=true
endif
endif
endif

#
# Catch-all rules
#
.PHONY: all
all: $(bower_deps)

.PHONY: clean
clean: clean-deps clean-dist clean-build

#
# Basic required tools
#
$(COMPOSER_BIN):
	mkdir -p $(build_dir)
	cd $(build_dir) && curl -sS https://getcomposer.org/installer | php

#
# ownCloud core PHP dependencies
#
$(composer_deps): $(COMPOSER_BIN) composer.json composer.lock
	php $(COMPOSER_BIN) install --no-dev

$(composer_dev_deps): $(COMPOSER_BIN) composer.json composer.lock
	php $(COMPOSER_BIN) install --dev


#
## Node dependencies
#
$(nodejs_deps): package.json
	$(NPM) install --prefix $(NODE_PREFIX) && touch $@

$(BOWER): $(nodejs_deps)
$(JSDOC): $(nodejs_deps)

$(bower_deps): $(BOWER)
	$(BOWER) install && touch $@

#
# dist
#
$(dist_dir)/$(app_name): $(bower_deps)
	rm -Rf $@; mkdir -p $@
	cp -R $(all_src) $@

ifdef CAN_SIGN
	$(sign) --path="$(dist_dir)/$(app_name)"
else
	@echo $(sign_skip_msg)
endif
	tar -czf $(dist_dir)/$(app_name).tar.gz -C $(dist_dir) $(app_name)
	tar -cjf $(dist_dir)/$(app_name).tar.bz2 -C $(dist_dir) $(app_name)

.PHONY: dist
dist: clean-dist $(dist_dir)/$(app_name)

.PHONY: clean-dist
clean-dist:
	rm -Rf $(dist_dir)

.PHONY: clean-build
clean-build:
	rm -Rf $(build_dir)

.PHONY: clean-deps
clean-deps:
	rm -Rf $(nodejs_deps) $(bower_deps) ${composer_deps}


.PHONY: test-php-style
test-php-style: $(composer_dev_deps)
	$(composer_deps)/bin/php-cs-fixer fix -v --diff --diff-format udiff --dry-run --allow-risky yes
