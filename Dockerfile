FROM ubuntu as builder

RUN apt update

RUN set -ex \
	&& apt install -y \
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
    wget \
    libssl-dev \
		perl \
    libperl-dev \
    libipc-run-perl \
    python-dev \
		python3-dev \
		git

RUN mkdir /pg-src

RUN cd /pg-src && git clone --depth 1 -b REL_11_STABLE https://github.com/postgres/postgres

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

RUN cd /pg-src/postgres && make -C contrib install

RUN cd /pg-src/postgres/contrib/ \
   && git clone https://github.com/postgrespro/jsquery \
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

RUN set -ex && apt install -y \
    bash \
    binutils-gold \
    curl \
    g++ \
    gcc \
    git \
    libicu-dev \
    linux-headers-generic \
    make \
    python \
    pkg-config \
    wget \
    findutils \
    libc++-dev \
    libc++abi-dev

RUN cd /pg-src/postgres/contrib/ \
   && git config --global user.email "you@example.com" \
   && git config --global user.name "Your Name" \
   && git clone --depth=1 https://github.com/plv8/plv8 \
   && cd plv8 \
   && export PATH=/pg/bin:$PATH \
   && export PG_CONFIG=/pg/bin/pg_config \
   && make \
   && make install

FROM ubuntu

RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
libc++-dev libxml2 libedit-dev openssl tzdata locales gosu \
&& rm -rf /var/lib/apt/lists/*


WORKDIR /pg

COPY --from=builder /pg /pg

RUN locale-gen en_US.UTF-8

ENV PATH /pg/bin:$PATH
ENV PGDATA /data
ENV LANG en_US.utf8

RUN adduser postgres \
--system \
--shell /bin/sh \
--group \
--disabled-password

RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA" # this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
VOLUME /data

ENV LD_LIBRARY_PATH /pg/lib

# ENTRYPOINT ["/entry-point.sh"]
CMD ["postgres"]
