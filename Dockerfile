FROM alpine:3.7 as builder

RUN set -ex \
	&& apk add --no-cache --virtual .fetch-deps \
		ca-certificates \
		openssl \
		tar \
		bison \
		coreutils \
		dpkg-dev dpkg \
		flex \
		gcc \
		libc-dev \
		libedit-dev \
		libxml2-dev \
		libxslt-dev \
		make \
		openssl-dev \
		perl \
    perl-ipc-run \
		perl-dev \
		util-linux-dev \
    python-dev \
		python3-dev \
		git \
		zlib-dev

RUN mkdir /pg-src

RUN cd /pg-src && git clone --depth 1 -b REL_10_STABLE https://github.com/postgres/postgres

# install OSSP uuid (http://www.ossp.org/pkg/lib/uuid/)
ENV OSSP_UUID_VERSION 1.6.2
ENV OSSP_UUID_SHA256 11a615225baa5f8bb686824423f50e4427acd3f70d394765bdff32801f0fd5b0

RUN mkdir -p /pg

RUN cd /pg-src \
  && wget -O uuid.tar.gz "https://www.mirrorservice.org/sites/ftp.ossp.org/pkg/lib/uuid/uuid-$OSSP_UUID_VERSION.tar.gz" \
	&& mkdir -p /usr/src/ossp-uuid \
	&& tar \
		--extract \
		--file uuid.tar.gz \
		--directory /usr/src/ossp-uuid \
		--strip-components 1 \
	&& rm uuid.tar.gz \
  && cd /usr/src/ossp-uuid \
  && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
  && wget -O config.guess 'https://git.savannah.gnu.org/cgit/config.git/plain/config.guess?id=7d3d27baf8107b630586c962c057e22149653deb' \
  && wget -O config.sub 'https://git.savannah.gnu.org/cgit/config.git/plain/config.sub?id=7d3d27baf8107b630586c962c057e22149653deb' \
  && ./configure --build="$gnuArch" --prefix=/pg \
  && make -j "$(nproc)" \
  && make install

ENV LD_LIBRARY_PATH /pg/lib

RUN cd /pg-src/postgres && \
  ./configure \
      --prefix=/pg \
      --build="$gnuArch" \
      --with-includes=/pg/include \
      --with-libraries=/pg/lib \
      --bindir=/pg/bin \
      --with-system-tzdata=/usr/share/zoneinfo \
      --enable-integer-datetimes \
      --enable-thread-safety \
      --enable-tap-tests \
      --with-ossp-uuid \
      --disable-rpath \
      --with-gnu-ld \
      --with-pgport=5432 \
  		--with-perl \
      --with-openssl \
      --with-libxml \
      --with-libxslt \
  		--with-python \
    && make -j 4 world || echo 'ups' \
    && make install

#		--enable-debug \
#		--with-pam \

RUN cd /pg-src/postgres && make -C contrib install

RUN cd /pg-src/postgres/contrib/ \
   && git clone -b filtering https://github.com/postgrespro/jsquery \
   && cd jsquery \
   && make \
   && make install

RUN cd /pg-src/postgres/contrib/ \
   && git clone https://github.com/eulerto/wal2json.git \
   && cd wal2json \
   && PATH=/pg/bin:$PATH \
   && make \
   && make install

RUN cd /pg-src/postgres/contrib/ \
   && git clone https://github.com/niquola/jsonknife \
   && cd jsonknife \
   && PATH=/pg/bin:$PATH \
   && make \
   && make install

# RUN set -ex && apk add --no-cache --virtual .fetch-deps \
#     bash \
#     binutils-gold \
#     curl \
#     g++ \
#     gcc \
#     git \
#     icu-dev \
#     linux-headers \
#     make \
#     python \
#     wget \
#     findutils

# RUN cd /pg-src/postgres/contrib/ \
#    && export DEPOT_TOOLS_WIN_TOOLCHAIN=0 \
#    && git clone -b v2.3.0 --depth=1 https://github.com/plv8/plv8 \
#    && cd plv8 \
#    && export PATH=/pg/bin:$PATH \
#    && export PG_CONFIG=/pg/bin/pg_config \
#    && make || make || make \
#    && make install

FROM alpine:3.7
RUN apk --no-cache add ca-certificates python3 openssl libxml2 libxslt libedit curl bash su-exec  tzdata
WORKDIR /pg
# RUN mkdir /data && chown postgres /data
COPY --from=builder /pg /pg

# RUN /pg/bin/initdb -D /data

ENV PATH /pg/bin:$PATH
ENV PGDATA /data
ENV LANG en_US.utf8

# COPY entry-point.sh /
# RUN chmod a+x /entry-point.sh

RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA" # this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
VOLUME /data

ENV LD_LIBRARY_PATH /pg/lib
# ENTRYPOINT ["/entry-point.sh"]
CMD ["postgres"]
