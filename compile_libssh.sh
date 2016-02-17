#!/bin/sh -e
# build libssh.4.dylib into Examtor directory.

# cmake is required! (brew install cmake ...)
export PATH=/usr/local/bin:$PATH
ME=`pwd`

### openssl for libssh (El Capitan dropped headers... and we want no homebrew dependency)

OPENSSL=1.0.2f

if [ ! -f openssl-build/lib/libssl.dylib ]; then
  mkdir -p openssl-build
  echo Downloading OpenSSL
  [ -d openssl-${OPENSSL} ] || curl -Ls https://www.openssl.org/source/openssl-${OPENSSL}.tar.gz | tar -xzf -
  cd openssl-${OPENSSL}
  ./Configure --prefix=$ME/openssl-build threads shared no-krb5 darwin64-x86_64-cc &> ssl_config.log
  echo Building OpenSSL
  perl -pi -e 's#-install_name [^"]+#-install_name \@executable_path/libcrypto.1.0.0.dylib#' Makefile.shared
  make -j8 &> ssl_make.log
  echo Installing OpenSSL into build directory ...
  make install &> ssl_install.log
  # drop manpages....!
  cd $ME
  cp openssl-build/lib/libcrypto.1.0.0.dylib .
  chmod 755 libcrypto.1.0.0.dylib
  install_name_tool -change $ME/openssl-build/lib/libcrypto.1.0.0.dylib @executable_path/libcrypto.1.0.0.dylib libcrypto.1.0.0.dylib
fi

### build libssh

if [ ! -f libssh.4.dylib ]; then
  echo Downloading libssh
  [ -d libssh ] || git clone git://git.libssh.org/projects/libssh.git libssh-source
  cd libssh-source
  mkdir -p build
  cd build
  echo Building libssh
  cmake -DWITH_ZLIB=OFF -WITH_GSSAPI=0 \
   -DCMAKE_LIBRARY_PATH=$ME/openssl-build/lib \
   -DCMAKE_INCLUDE_PATH=$ME/openssl-build/include \
   -DOPENSSL_CRYPTO_LIBRARY=$ME/openssl-build/lib/libcrypto.dylib \
   -DOPENSSL_INCLUDE_DIR=$ME/openssl-build/include \
   -DCMAKE_INSTALL_PREFIX=$ME/libssh-build \
   -DCMAKE_INSTALL_NAME_DIR=@executable_path ..
  make -j8
  make install
  cd ../..
  cp libssh-build/lib/libssh.4.dylib .
  grep -v '#include <libssh/libssh.h>' libssh-build/include/libssh/callbacks.h > Examator/callbacks.h
  grep -v '#include "libssh/legacy.h"' libssh-build/include/libssh/libssh.h > Examator/libssh.h
  cp libssh-build/include/libssh/{sftp,ssh2}.h Examator
  install_name_tool -change $ME/openssl-build/lib/libcrypto.1.0.0.dylib @executable_path/libcrypto.1.0.0.dylib libssh.4.dylib
  rm -rf libssh libssh-build
fi
