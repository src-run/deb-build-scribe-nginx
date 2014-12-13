# Nginx Mainline (Scribe Build)

This script builds a set of Nginx packages against the [Ubuntu Nginx Mainline Branch](http://ppa.launchpad.net/nginx/development/ubuntu), currently at version `1.7.8`, with an emphasis on producing a streamlined final binary that includes/excluded configuration flags and adds a short list of modules used internally by [Scribe Inc.](https://scribenet.com/)—for both our own websites and those we administer. 

*Very generally, this script simply pulls the latest Nginx mainline source and adds any additional files, applies any relivant patches, clones any relivant modules and external dependencies. It can then run a handlful of build operations against the resulting source.*

## Supported Ubuntu Releases

At this time, the build script does a simply check that you are running a supported Ubuntu version: `Trusty 14.04` or `Utopic 14.10`. With that said, it should be trivial to to support later releases of Ubuntu—the version check simply means *I haven't tested it on that enviornment yet*, not that it is incompatable.

## Bootstrap Configuration

Before runing the `bootstrap.sh` script, it is important to familiarize (and generally customize) the configuration options available. Neglecting to do so will not provide optimal results.

The following are key configuration items:

- `BUILD_SIGNING_KEY_ID`

  Your PGP siging key, used to sign your source and package files. By default this script runs with `--force-sign` enabled, and will not exit successfully if you don't change the signing key. For more information, see the [Ubuntu Help Docs](https://help.ubuntu.com/community/GnuPrivacyGuardHowto).

- `BUILD_MODE`
  
  This script can run in a number of build modes that dictate its behaviour after the intial boostrap. The `BUILD_MODE` is defined by assigning it one of the following numeric options:
  
  - [`1`] Generate source and binary packages locally in your current (non-sanatized) enviornment. This will result in packages that *should* be capable of installation on any target system of the same release.

  - [`2`] Generate source packages only (generally for a PPA upload)
  
  - [`3`] Generate source packages only (and perform the PPA upload automatically)
  
  - [`4`] Perform a test build using SimpleSbuild, a sanitized enviornment similar to the automated builders used by Launchpad.



- `BUILD_LAUNCHPAD_URL`

  In order to take advantage of build option `3` and have your source files automatically uploaded to Launchpad upon successful source generation, this must be configured to your Laucnhpad PPA path.

- `SBUILD_DIST`

  In order to take advantage of build option `4` and run your build using SimpleSbuild locally (to mimic a similar enviornment to Launchpad's automated builders), this option must be set to an installed distribution name. Assumes SimpleSBuild has been setup per the 
  [Ubuntu Wiki on SimpleSbuild](https://wiki.ubuntu.com/SimpleSbuild).

- `OPT_DPKG_BUILDPACKAGE`

  If you only plan on using option one for testing purposes and do not need your files signed, you must remove the `--force-sign -k${BUILD_SIGNING_KEY_ID}` line from the `OPT_DPKG_BUILDPACKAGE` variable. Otherwise, if you haven't setup a GPG key and updated the changelog to reflect your name and e-mail address, the build will fail.

## Build Configuration

### Flags

The following configuration flags—*generallty not compiled by default*—are *explicitly enabled* in this build:

- `IPv6`, *--with-ipv6*

  Enable IPv6 support within Nginx.

- `debug`, *--with-debug*

  Allow verbose debug-level logging output. *(While this should not be enabled on a production enviornment, allowing for debug output to be turned on enables viewing advanced, low-level information about a request cycle.)*

- `PCRE`, *--with-pcre*

  Compile and link against non-system PCRE. Instead, grab the latest release and explicitly enable JIT support. *(JIT support is broken in libpcre package provided by Ubuntu Trusty repository)*

- `PCRE JIT`, *--with-pcre-jit*

  Enable PCRE Just-In-Time (JIT) regular expression compilation. *(Substantial performance gains on regex-heavy server configurations, requires statically linking PCRE to during compilation.)*

- `AIO`, *--with-file-aio*

  Enable kernel asynchronous I/O support. *(Allows the process that requests an IO operation to not be blocked if the data is unavailable; execution continues and the process can later check the status of the submitted IO request.)*

The following config flags—*generally compiled by default*—are *explicitly disabled* in this build:

- `Poll and Select`, *--without-poll_module* and *--without-select_module*

  We don't need these as we can use the `epoll` event model which is preferable on a Linux kernel *>2.6* enviornment. See http://wiki.nginx.org/Optimizations

- `UWSGI`, *--without-http_uwsgi_module*

  We don't use uWSGI for any of our services. See https://uwsgi-docs.readthedocs.org/en/latest/

### Modules

The following modules are compiled into Nginx with this release:

- [`http_ssl_module`](http://nginx.org/en/docs/http/ngx_http_ssl_module.html)

  Provides the necessary support for HTTPS.

- [`http_stub_status_module`](http://nginx.org/en/docs/http/ngx_http_stub_status_module.html)

  Provides access to basic status information.

- [`http_geoip_module`](http://nginx.org/en/docs/http/ngx_http_geoip_module.html)

  Creates variables with values depending on the client IP address, using the precompiled [MaxMind](http://www.maxmind.com/) databases.

- [`http_spdy_module`](http://nginx.org/en/docs/http/ngx_http_spdy_module.html)

  Provides experimental support for [SPDY](http://www.chromium.org/spdy/spdy-protocol). Currently implements [draft 3.1](http://www.chromium.org/spdy/spdy-protocol/spdy-protocol-draft3-1).
  
- [`nginx_auth-pam`](http://web.iti.upv.es/~sto/nginx/ngx_http_auth_pam_module-1.3/)

  Enables HTTP Basic Authentication agains PAM.
  
- [`nginx-development-kit`](https://github.com/simpl/ngx_devel_kit)

  Module that adds additional generic tools that module developers can use in their own modules (required for some of the following modules).
  
- [`nginx_upload_progress_module`](https://github.com/masterzen/nginx-upload-progress-module/tree/master)

  An implementation of an upload progress system, that monitors RFC1867 POST upload as they are transmitted to upstream servers.
 
- [`ngx_pagespeed`](https://github.com/pagespeed/ngx_pagespeed)

  ngx_pagespeed speeds up your site and reduces page load time by automatically applying web performance best practices to 
  pages and associated assets (CSS, JavaScript, images) without requiring you to modify your existing content or workflow.

## Usage

```
git clone https://github.com/scribenet/nginx-scribe.git && cd nginx-scribe
[nano/vim] bootstrap.sh
./bootstrap.sh
```
