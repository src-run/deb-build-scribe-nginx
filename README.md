# Nginx (Scribe Flavor)

This is a build script that pulls the 
[Ubuntu Nginx Development Branch](http://ppa.launchpad.net/nginx/development/ubuntu) 
using `apt-get source nginx`, applies a collection of patch files to add/remove `rules` from
the debian configuration scripts, and finally runs `dpkg-buildpackage` to build the custom 
Nginx packages.

## Packages

Unlike the official Nginx packages, this doesn't compile the `nginx-[light|full|extras]` variants: this create the `nginx-common` package as well as an `nginx-script` package.

## Configuration

Below you can find a detailed rundown of enabled/disabled flags as well as the optional upstream Nginx modules and third-party modules compiled in.

### Flags

The following configuration flags—*generallty not compiled by default*—are **explicitly enabled** in this build:

- `debug`, *--with-debug*

  Allow verbose debug-level logging output. *(While this should not be enabled on a production enviornment, allowing for debug output to be turned on enables viewing advanced, low-level information about a request cycle.)*

- `PCRE`, *--with-pcre*

  Compile and link against non-system PCRE. Instead, grab the latest release and explicitly enable JIT support. *(JIT support is broken in libpcre package provided by Ubuntu Trusty repository)*

- `PCRE JIT`, *--with-pcre-jit*

  Enable PCRE Just-In-Time (JIT) regular expression compilation. *(Substantial performance gains on regex-heavy server configurations)*

- `AIO`, *--with-file-aio*

  Enable kernel asynchronous I/O support. *(Allows the process that requests an IO operation to not be blocked if the data is unavailable; execution continues and the process can later check the status of the submitted IO request.)*

The following config flags—*generally compiled by default*—are **explicitly disabled** in this build:

- [`poll_module and select_module`](http://wiki.nginx.org/Optimizations) 

  *--without-poll_module *and* --without-select_module*

  We don't need these as we can use the `epoll` event model which is preferable on a Linux kernel *>2.6* enviornment.

- [`http_uwsgi_module`](https://uwsgi-docs.readthedocs.org/en/latest/) 

  *--without-http_uwsgi_module*

  We don't use uWSGI for any of our services.

### Modules

The following modules are compiled into Nginx with this release:

- [`http_ssl_module`](http://nginx.org/en/docs/http/ngx_http_ssl_module.html)

  Provides the necessary support for HTTPS.

- [`http_stub_status_module`](http://nginx.org/en/docs/http/ngx_http_stub_status_module.html)

  Provides access to basic status information.

- [`http_realip_module`](http://nginx.org/en/docs/http/ngx_http_realip_module.html)

  Used to change the client address to the one sent in the specified header field.

- [`http_auth_request_module`](http://nginx.org/en/docs/http/ngx_http_auth_request_module.html)

  Implements client authorization based on the result of a subrequest.

- [`http_addition_module`](http://nginx.org/en/docs/http/ngx_http_addition_module.html)

  Filter that adds text before and after a response.

- [`http_dav_module`](http://nginx.org/en/docs/http/ngx_http_dav_module.html)

  File management automation via the WebDAV protocol.

- [`http_geoip_module`](http://nginx.org/en/docs/http/ngx_http_geoip_module.html)

  Creates variables with values depending on the client IP address, using the precompiled [MaxMind](http://www.maxmind.com/) databases.

- [`http_gzip_static_module`](http://nginx.org/en/docs/http/ngx_http_gzip_static_module.html)

  Allows sending precompressed files with the “.gz” filename extension instead of regular files.

- [`http_image_filter_module`](http://nginx.org/en/docs/http/ngx_http_image_filter_module.html)

  Filter that transforms images in JPEG, GIF, and PNG formats.

- [`http_mp4_module`](http://nginx.org/en/docs/http/ngx_http_mp4_module.html)

  Pseudo-streaming server-side support for MP4 files.

- [`http_perl_module`](http://nginx.org/en/docs/http/ngx_http_perl_module.html)

  Used to implement location and variable handlers in Perl and insert Perl calls into SSI.

- [`http_random_index_module`](http://nginx.org/en/docs/http/ngx_http_random_index_module.html)

  Processes requests ending with the slash character (‘/’) and picks a random file in a directory to serve as an index file.

- [`http_secure_link_module`](http://nginx.org/en/docs/http/ngx_http_secure_link_module.html)

  Used to check authenticity of requested links, protect resources from unauthorized access, and limit link lifetime.

- [`http_spdy_module`](http://nginx.org/en/docs/http/ngx_http_spdy_module.html)

  Provides experimental support for [SPDY](http://www.chromium.org/spdy/spdy-protocol). Currently implements [draft 3.1](http://www.chromium.org/spdy/spdy-protocol/spdy-protocol-draft3-1).

- [`http_sub_module`](http://nginx.org/en/docs/http/ngx_http_sub_module.html)

  Filter that modifies a response by replacing one specified string by another

- [`http_xslt_module`](http://nginx.org/en/docs/http/ngx_http_xslt_module.html)

  Filter that transforms XML responses using one or more XSLT stylesheets.

- [`headers-more-nginx-module`](https://github.com/openresty/headers-more-nginx-module)

  Adds to the "add" header ability with "set" and "clear".
  
- [`nginx_auth-pam`](http://web.iti.upv.es/~sto/nginx/ngx_http_auth_pam_module-1.3/)

  Enables HTTP Basic Authentication agains PAM.
  
- [`nginx_cache_purge`](https://github.com/FRiCKLE/ngx_cache_purge)

  Module which adds ability to purge content from FastCGI, proxy, SCGI and uWSGI caches.
  
- [`nginx-dav-ext-module`](https://github.com/arut/nginx-dav-ext-module)

  Adds additional (missing) methods from the default Nginx WebDAV implementation.
  
- [`nginx-development-kit`](https://github.com/simpl/ngx_devel_kit)

  Module that adds additional generic tools that module developers can use in their own modules (required for some of the following modules).
  
- [`nginx-echo`](https://github.com/openresty/echo-nginx-module)

  Module for bringing the power of "echo", "sleep", "time" and more to Nginx's config file.
  
- [`ngx-fancyindex`](https://github.com/aperezdc/ngx-fancyindex)

  Provides absility to add custom headers, CSS, and sorting to default nginx folder index listing.
  
- [`nginx_http_push_module`](https://pushmodule.slact.net/)

  Module turns Nginx into an adept HTTP Push and Comet server.
  
- [`nginx_upload_progress_module`](https://github.com/masterzen/nginx-upload-progress-module/tree/master)

  An implementation of an upload progress system, that monitors RFC1867 POST upload as they are transmitted to upstream servers.
  
- [`nginx-upstream-fair`](https://github.com/gnosek/nginx-upstream-fair)

  The Nginx fair proxy balancer enhances the standard round-robin load balancer provided with Nginx so that it will track busy back end servers (e.g. Thin, Ebb, Mongrel) and balance the load to non-busy server processes.

- [`ngx_http_substitutions_filter_module`](https://github.com/yaoweibin/ngx_http_substitutions_filter_module)

  Filter which can do both regular expression and fixed string substitutions on response bodies.

- [`set-misc-nginx-module`](https://github.com/openresty/set-misc-nginx-module)

  Various set_xxx directives added to nginx's rewrite module (md5/sha1, sql/json quoting, and many more).

- [`array-var-nginx-module`](https://github.com/openresty/array-var-nginx-module)

  Add support for array variables to nginx config files.

- [`drizzle-nginx-module`](https://github.com/openresty/drizzle-nginx-module)

  Provides a very efficient and flexible way for nginx internals to access MySQL, Drizzle, as well as other RDBMS's that support the Drizzle or MySQL wired protocol.

- [`rds-json-nginx-module`](https://github.com/openresty/rds-json-nginx-module)

  Filter that formats Resty DBD Streams generated by ngx_drizzle to JSON.

- [`rds-csv-nginx-module`](https://github.com/openresty/rds-csv-nginx-module)

  Filter that formats Resty DBD Streams generated by ngx_drizzle to CSV.

- [`memc-nginx-module`](https://github.com/openresty/memc-nginx-module)

  Extended version of the standard memcached module that supports set, add, delete, and many more memcached commands.

- [`srcache-nginx-module`](https://github.com/openresty/srcache-nginx-module)

  Transparent subrequest-based caching layout for arbitrary nginx locations.


## Package Requirements

- perl *(>5.6.1)*
- libreadline-dev
- libssl-dev