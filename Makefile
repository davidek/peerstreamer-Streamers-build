BASEDIR := $(shell pwd)
THIRDPARTYLIBS := $(BASEDIR)/THIRDPARTY-LIBS

NOGIT := $(shell [ -d .git ] || echo 1)
REV := $(shell ( [ -d .git ] && git describe --tags --always --dirty 2>/dev/null ) || ( [ -d .git ] && git describe --tags --always 2>/dev/null ) || ( [ -d .git ] && git describe --tags ) || ( [ -d .svn ] && svnversion ) || echo exported)
DIR := PeerStreamer-$(subst PeerStreamer-,,$(REV))

ARCH:=$(shell uname -m)
ifeq ($(ARCH),x86_64)
	ARCH=amd64
endif
ifeq  ($(ARCH),i386)
	ARCH=i386
endif
ifeq  ($(ARCH),i686)
	ARCH=i386
endif

UNAME := $(shell uname)
ifeq ($(UNAME), Linux)
  # do something Linux-y
  STATIC ?= 2
  XSTATIC = -static
  LINUX_OS = 1
endif
ifeq ($(UNAME), Darwin)
  # do something OSX-y
  STATIC = 0
  XSTATIC =
  MAC_OS = 1
endif
STATIC ?= 2
XSTATIC ?= -static

FLAGS_CHUNKER += LOCAL_FFMPEG=$(THIRDPARTYLIBS)/ffmpeg-install
FLAGS_CHUNKER += LOCAL_X264=$(THIRDPARTYLIBS)/x264-install 
FLAGS_CHUNKER += LOCAL_MP3LAME=$(THIRDPARTYLIBS)/mp3lame-install
ifeq (,$(findstring mingw32,$(HOSTARCH)))
FLAGS_CHUNKER += LOCAL_LIBOGG=$(THIRDPARTYLIBS)/libogg-install
FLAGS_CHUNKER += LOCAL_LIBVORBIS=$(THIRDPARTYLIBS)/libvorbis-install
else
EXE =.exe
endif

.PHONY: $(THIRDPARTYLIBS) update clean ml-chunkstream $(DIR)

all: $(DIR)

simple: Streamers/streamer-udp-grapes$(EXE)
ml: Streamers/streamer-ml-monl-grapes$(XSTATIC)$(EXE)
chunkstream: Streamers/streamer-udp-chunkstream$(EXE) ChunkerPlayer/chunker_player/chunker_player$(EXE)
ml-chunkstream: Streamers/streamer-ml-monl-chunkstream$(XSTATIC)$(EXE) ChunkerPlayer/chunker_player/chunker_player$(EXE)

$(THIRDPARTYLIBS):
	$(MAKE) -C $(THIRDPARTYLIBS) || { echo "Error preparing third party libs" && exit 1; }

ifndef NOGIT
update:
	git pull
	git submodule sync
	git submodule update

forceupdate:
	git stash
	git pull
	git submodule foreach git stash
	git submodule sync
	git submodule update

Streamers/.git:
	git submodule init -- $(shell dirname $@)
	git submodule update -- $(shell dirname $@)

Streamers/streamer-grapes: Streamers/.git
Streamers/streamer-ml-monl-grapes$(XSTATIC)$(EXE): Streamers/.git
Streamers/streamer-chunkstream$(EXE): Streamers/.git
Streamers/streamer-ml-monl-chunkstream$(XSTATIC)$(EXE): Streamers/.git

ChunkerPlayer/.git:
	git submodule init -- $(shell dirname $@)
	git submodule update -- $(shell dirname $@)

ChunkerPlayer/chunker_player/chunker_player$(EXE): ChunkerPlayer/.git
endif

#.PHONY: Streamers/streamer-grapes Streamers/streamer-ml-monl-grapes$(XSTATIC)$(EXE) Streamers/streamer-chunkstream$(EXE) Streamers/streamer-ml-monl-chunkstream$(XSTATIC)$(EXE)
Streamers/streamer-udp-grapes$(EXE): $(THIRDPARTYLIBS)
	cd Streamers && ./configure \
	--with-ldflags="`cat $(THIRDPARTYLIBS)/ffmpeg.ldflags`" --with-ldlibs="`cat $(THIRDPARTYLIBS)/ffmpeg.ldlibs`" \
	--with-grapes=$(THIRDPARTYLIBS)/GRAPES --with-ffmpeg=$(THIRDPARTYLIBS)/ffmpeg \
	--with-net-helper=udp \
	--with-static=$(STATIC)
	$(MAKE) -C Streamers

#version with NAPA-libs
Streamers/streamer-ml-monl-grapes$(XSTATIC)$(EXE): $(THIRDPARTYLIBS)
	cd Streamers && ./configure \
	--with-ldflags="`cat $(THIRDPARTYLIBS)/ffmpeg.ldflags`" --with-ldlibs="`cat $(THIRDPARTYLIBS)/ffmpeg.ldlibs`" \
	--with-grapes=$(THIRDPARTYLIBS)/GRAPES --with-ffmpeg=$(THIRDPARTYLIBS)/ffmpeg \
	--with-napa=$(THIRDPARTYLIBS)/NAPA-BASELIBS/ --with-libevent=$(THIRDPARTYLIBS)/NAPA-BASELIBS/3RDPARTY-LIBS/libevent \
	--with-net-helper=ml --with-monl \
	--with-static=$(STATIC)
	$(MAKE) -C Streamers

Streamers/streamer-udp-chunkstream$(EXE): $(THIRDPARTYLIBS)
	cd Streamers && ./configure \
	--with-io=chunkstream \
	--with-grapes=$(THIRDPARTYLIBS)/GRAPES --with-ffmpeg=$(THIRDPARTYLIBS)/ffmpeg \
	--with-net-helper=udp \
	--with-static=$(STATIC)
	$(MAKE) -C Streamers

Streamers/streamer-ml-monl-chunkstream$(XSTATIC)$(EXE): $(THIRDPARTYLIBS)
	cd Streamers && ./configure \
	--with-io=chunkstream \
	--with-grapes=$(THIRDPARTYLIBS)/GRAPES --with-ffmpeg=$(THIRDPARTYLIBS)/ffmpeg \
	--with-napa=$(THIRDPARTYLIBS)/NAPA-BASELIBS/ --with-libevent=$(THIRDPARTYLIBS)/NAPA-BASELIBS/3RDPARTY-LIBS/libevent \
	--with-net-helper=ml --with-monl \
	--with-static=$(STATIC)
	$(MAKE) -C Streamers

ChunkerPlayer/chunker_player/chunker_player$(EXE): $(THIRDPARTYLIBS)
	cd ChunkerPlayer && $(FLAGS_CHUNKER) ./build_ul.sh

prepare:
ifndef NOGIT
	git submodule init
	git submodule update
else
	git clone http://halo.disi.unitn.it/~cskiraly/PublicGits/ffmpeg.git THIRDPARTY-LIBS/ffmpeg
	cd THIRDPARTY-LIBS/ffmpeg && git checkout -b streamer 210091b0e31832342322b8461bd053a0314e63bc
	git clone git://git.videolan.org/x264.git THIRDPARTY-LIBS/x264
	cd THIRDPARTY-LIBS/x264 && git checkout -b streamer 08d04a4d30b452faed3b763528611737d994b30b
endif

clean:
	$(MAKE) -C $(THIRDPARTYLIBS) clean
	$(MAKE) -C Streamers clean
	$(MAKE) -C ChunkerPlayer/chunker_player clean
	$(MAKE) -C ChunkerPlayer/chunk_transcoding clean
	$(MAKE) -C ChunkerPlayer/chunker_streamer clean
ifdef MAC_OS
	rm -rf *.app *.dmg
endif

distclean:
	$(MAKE) -C $(THIRDPARTYLIBS) distclean
	$(MAKE) -C Streamers clean
	$(MAKE) -C ChunkerPlayer/chunker_player clean
	$(MAKE) -C ChunkerPlayer/chunk_transcoding clean
	$(MAKE) -C ChunkerPlayer/chunker_streamer clean

pack:  $(DIR)-stripped.tgz

$(DIR):  Streamers/streamer-ml-monl-chunkstream$(XSTATIC)$(EXE) ChunkerPlayer/chunker_player/chunker_player$(EXE)
	rm -rf $(DIR) $(DIR).tgz $(DIR)-stripped.tgz
	mkdir $(DIR)
	cp Streamers/streamer-ml-monl-chunkstream$(XSTATIC)$(EXE) $(DIR)
	cp ChunkerPlayer/chunker_player/chunker_player$(EXE) $(DIR)
	mkdir $(DIR)/icons
	cp ChunkerPlayer/chunker_player/icons/* $(DIR)/icons
	cp ChunkerPlayer/chunker_player/stats_font.ttf ChunkerPlayer/chunker_player/mainfont.ttf ChunkerPlayer/chunker_player/napalogo_small.bmp $(DIR)
	echo streamer-ml-monl-chunkstream$(XSTATIC)$(EXE) > $(DIR)/peer_exec_name.conf
	cp ChunkerPlayer/chunker_streamer/chunker_streamer$(EXE) ChunkerPlayer/chunker_streamer/chunker.conf $(DIR)
ifeq (,$(findstring mingw32,$(HOSTARCH)))
	ln -s streamer-ml-monl-chunkstream$(XSTATIC)$(EXE) $(DIR)/streamer
	cp scripts/source.sh $(DIR)
	cp scripts/player.sh $(DIR)
else
	cp scripts/peerstreamer.bat $(DIR)
	cp scripts/runQuietly.vbs $(DIR)
endif
	cp channels.conf $(DIR)
	cp README $(DIR)

$(DIR).tgz: $(DIR)
	tar czf $(DIR).tgz $(DIR)

$(DIR)-stripped.tgz: $(DIR).tgz
ifeq (,$(findstring mingw32,$(HOSTARCH)))
	cd $(DIR) && strip chunker_streamer$(EXE)
endif
	cd $(DIR) && strip streamer-ml-monl-chunkstream$(XSTATIC)$(EXE) chunker_player$(EXE)
ifeq (,$(findstring mingw32,$(HOSTARCH)))
	tar czf $(DIR)-stripped.tgz $(DIR)
else
	zip -r $(DIR).zip $(DIR)
endif

install: $(DIR)
	mkdir -p /opt/peerstreamer
	cp -r $(DIR)/* /opt/peerstreamer
	ln -f -s /opt/peerstreamer/player.sh /usr/local/bin/peerstreamer
	cp -r Installer/Lin/usr/share /usr

uninstall:
	rm -rf /opt/peerstreamer
	rm -f /usr/local/bin/peerstreamer
	rm -rf /usr/share/applications/peerstreamer.desktop
	rm -rf /usr/share/menu/peerstreamer
	rm -rf /usr/share/pixmaps/peerstreamer.xpm

ifdef LINUX_OS
debian:
	@echo Debian packaging for $(ARCH)
ifneq (, $(filter $(ARCH),amd64 $(ARCH) i686))
	rm -rf package && mkdir package
	cd package && mkdir -p peerstreamer_$(subst PeerStreamer-,,$(REV))-1_$(ARCH) && curl http://peerstreamer.org/files/release/barepackage.tgz| tar xz -C peerstreamer_$(subst PeerStreamer-,,$(REV))-1_$(ARCH)
	cd package && sed -i "s/ARCHITECTURE/$(ARCH)/g" peerstreamer_$(subst PeerStreamer-,,$(REV))-1_$(ARCH)/DEBIAN/control 
	cd package && sed -i "s/VERSION/$(subst PeerStreamer-,,$(REV))/g" peerstreamer_$(subst PeerStreamer-,,$(REV))-1_$(ARCH)/DEBIAN/control
	cp -r $(DIR)/* package/peerstreamer_$(subst PeerStreamer-,,$(REV))-1_$(ARCH)/opt/peerstreamer
	cp Installer/Lin/usr/share/pixmaps/eit-napa.svg package/peerstreamer_$(subst PeerStreamer-,,$(REV))-1_$(ARCH)/opt/peerstreamer
	cd package && fakeroot dpkg --build peerstreamer_$(subst PeerStreamer-,,$(REV))-1_$(ARCH)
	tar -czvf package/$(DIR).tgz $(DIR)	
else 
	$(error Architecture not found $(ARCH))
endif

rpm: TMPDIR:=$(shell mktemp -d)
rpm: debian
	cp package/$(subst PeerStreamer-,peerstreamer_,$(DIR))-1_$(ARCH).deb $(TMPDIR)
	cd $(TMPDIR) && alien -r $(subst PeerStreamer-,peerstreamer_,$(DIR))-1_$(ARCH).deb -v --fixperms -k
ifeq ($(ARCH),i386)
	mv $(TMPDIR)/$(subst PeerStreamer_,peerstreamer-,$(subst -,_,$(DIR)))-1.i386.rpm package/
else
	mv $(TMPDIR)/$(subst PeerStreamer_,peerstreamer-,$(subst -,_,$(DIR)))-1.x86_64.rpm package/
endif
	rm -rf $(TMPDIR)
endif

ifneq (,$(findstring mingw32,$(HOSTARCH)))
installer-win: $(DIR)
	ln -s $(DIR) PeerStreamer
	makensis -DPRODUCT_VERSION="$(subst PeerStreamer-,,$(REV))" Installer/Win/peerstreamer.nsi
	rm PeerStreamer
	mv Installer/Win/PeerStreamerInstaller*.exe .
endif

ifdef MAC_OS
installer-OSX: $(DIR)
	cd Installer/OSX/ && tar zfx OSX_template.tgz && ./makeApp.sh $(DIR) && rm -rf napa-template.app && make VERSION=$(REV) && mv $(REV).dmg ../../
endif
