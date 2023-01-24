# Based on c_src.mk from erlang.mk by Loic Hoguin <essen@ninenines.eu>

CURDIR := $(shell pwd)
BASEDIR := $(abspath $(CURDIR))

PROJECT ?= $(notdir $(BASEDIR))
PROJECT := $(strip $(PROJECT))

ERTS_INCLUDE_DIR ?= $(shell erl -noshell -s init stop -eval "io:format(\"~s/erts-~s/include/\", [code:root_dir(), erlang:system_info(version)]).")

C_SRC_DIR = $(CURDIR)
C_SRC_OUTPUT ?= $(CURDIR)/priv/ecsv.so

# System type and C compiler/flags.

UNAME_SYS := $(shell uname -s)
ifeq ($(UNAME_SYS), Darwin)
	CC ?= cc
	CFLAGS ?= -O3 -std=c99 -arch x86_64 -finline-functions -Wall -Wextra
	CXXFLAGS ?= -O3 -arch x86_64 -finline-functions -Wall
	LDFLAGS ?= -arch x86_64 -undefined dynamic_lookup -dynamiclib
else ifeq ($(UNAME_SYS), FreeBSD)
	CC ?= cc
	CFLAGS ?= -O3 -std=c99 -finline-functions -Wall -Wextra
	CXXFLAGS ?= -O3 -finline-functions -Wall
else ifeq ($(UNAME_SYS), Linux)
	CC ?= gcc
	CFLAGS ?= -O3 -std=c99 -finline-functions -Wall -Wextra
	CXXFLAGS ?= -O3 -finline-functions -Wall -shared
	LDFLAGS ?= -shared
endif

CFLAGS += -g -fvisibility=hidden -fPIC -I $(ERTS_INCLUDE_DIR)
CXXFLAGS += -fPIC -I $(ERTS_INCLUDE_DIR)

LDLIBS += -lcsv
LDFLAGS += -fPIC

# Verbosity.

c_verbose_0 = @echo " C     " $(?F);
c_verbose = $(c_verbose_$(V))

cpp_verbose_0 = @echo " CPP   " $(?F);
cpp_verbose = $(cpp_verbose_$(V))

link_verbose_0 = @echo " LD    " $(@F);
link_verbose = $(link_verbose_$(V))

SOURCES := $(shell find $(C_SRC_DIR) -type f \( -name "*.c" -o -name "*.C" -o -name "*.cc" -o -name "*.cpp" \))
OBJECTS = $(addsuffix .o, $(basename $(SOURCES)))

COMPILE_C = $(c_verbose) $(CC) $(CFLAGS) $(CPPFLAGS) -c
COMPILE_CPP = $(cpp_verbose) $(CXX) $(CXXFLAGS) $(CPPFLAGS) -c

all: $(C_SRC_OUTPUT)

# pull in dependency info for *existing* .o files
-include $(OBJECTS:.o=.d)

$(C_SRC_OUTPUT): $(OBJECTS)
	@mkdir -p $(BASEDIR)/priv/
	$(link_verbose) $(CC) $(OBJECTS) $(LDFLAGS) $(LDLIBS) -o $(C_SRC_OUTPUT)

%.o: %.c
	$(COMPILE_C) $(OUTPUT_OPTION) $<
	$(CC) -MM $(CFLAGS) $< > $*.d

%.o: %.cc
	$(COMPILE_CPP) $(OUTPUT_OPTION) $<
	$(CXX) -MM $(CFLAGS) $< > $*.d

%.o: %.C
	$(COMPILE_CPP) $(OUTPUT_OPTION) $<
	$(CXX) -MM $(CFLAGS) $< > $*.d

%.o: %.cpp
	$(COMPILE_CPP) $(OUTPUT_OPTION) $<
	$(CXX) -MM $(CFLAGS) $< > $*.d

clean:
	@rm -f $(C_SRC_OUTPUT) $(OBJECTS) $(OBJECTS:.o=.d)
