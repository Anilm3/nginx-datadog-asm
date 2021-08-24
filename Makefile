NGINX_VERSION = 1.18.0
# TODO: Consider renaming the module/ directory.
MODULE_PATH := $(realpath module/)
MODULE_NAME = ngx_http_opentracing_module
CLONE = git -c advice.detachedHead=false clone

.PHONY: all
all: nginx-module.cmake dd-opentracing-cpp-deps

.PHONY: build
build: all
	mkdir -p .build && cd .build && cmake -DBUILD_TESTING=OFF .. && make -j VERBOSE=1

.PHONY: dd-opentracing-cpp-deps
dd-opentracing-cpp-deps: dd-opentracing-cpp/deps/include/curl dd-opentracing-cpp/deps/include/msgpack

dd-opentracing-cpp/deps/include/curl dd-opentracing-cpp/deps/include/msgpack: dd-opentracing-cpp/scripts/install_dependencies.sh
	cd dd-opentracing-cpp && ./scripts/install_dependencies.sh not-opentracing
	touch $@

nginx-module.cmake: nginx_build_info.json bin/generate_cmakelists.py
	bin/generate_cmakelists.py nginx_module >$@ <$<

nginx_build_info.json: nginx/objs/Makefile bin/makefile_database.py
	bin/makefile_database.py nginx/objs/Makefile $(MODULE_NAME) >$@

nginx/objs/Makefile: nginx/ $(MODULE_PATH)/config
	cd nginx && auto/configure --add-dynamic-module=$(MODULE_PATH)\
	                           --with-compat \
							   --without-http_rewrite_module \
							   --without-http_gzip_module
	
$(MODULE_PATH)/config:
	bin/module_config.sh $(MODULE_NAME) >$@

nginx/:
	$(CLONE) --depth 1 --branch release-$(NGINX_VERSION) https://github.com/nginx/nginx

.PHONY: format
format:
	yapf -i bin/*.py

.PHONY: clean
clean:
	rm -rf \
		$(MODULE_PATH)/config \
		nginx_build_info.json \
		.build \
		nginx-module.cmake \
	
.PHONY: clobber
clobber: clean
	rm -rf \
	    nginx \
		dd-opentracing-cpp/deps

.PHONY: build-in-docker
build-in-docker: all
	docker build --tag nginx-module-cmake-build .
	bin/run_in_build_image.sh bin/cmake_build.sh .docker-build

.PHONY: test
test: build-in-docker
	cd test && DD_API_KEY=$$(cat ~/.dd-keys/default/api-key) $(MAKE) up
