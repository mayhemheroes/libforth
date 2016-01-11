ECHO=echo
AR=ar
CC=gcc
CFLAGS=-Wall -Wextra -g -pedantic -fPIC -std=c99
TARGET=forth

.PHONY: all clean doxygen

all: shorthelp $(TARGET) lib$(TARGET).so

shorthelp:
	@$(ECHO) "Use 'make help' for a list of all options"
help:
	@$(ECHO) ""
	@$(ECHO) "project:      lib$(TARGET)"
	@$(ECHO) "descriptions: A small FORTH interpreter and library"
	@$(ECHO) ""
	@$(ECHO) "make (option)*"
	@$(ECHO) ""
	@$(ECHO) "	all             create the $(TARGET) libraries and executables"
	@$(ECHO) "	$(TARGET)           create the $(TARGET) executable"
	@$(ECHO) "	unit            create the unit test executable"
	@$(ECHO) "	test            execute the unit tests"
	@$(ECHO) "	doc             make the project documentation"
	@$(ECHO) "	lib$(TARGET).so     make a shared $(TARGET) library"
	@$(ECHO) "	lib$(TARGET).a      make a static $(TARGET) library"
	@$(ECHO) "	clean           remove generated files"
	@$(ECHO) "	install         (TODO) install the project"
	@$(ECHO) "	uninstall       (TODO) uninstall the project"
	@$(ECHO) "	dist            (TODO) create a distribution archive"
	@$(ECHO) ""

doc: $(TARGET).htm doxygen
$(TARGET).htm: $(TARGET).md
	markdown $^ > $@
doxygen:
	doxygen doxygen.conf

lib$(TARGET).o: lib$(TARGET).c lib$(TARGET).h
	$(CC) $(CFLAGS) $< -c -o $@
lib$(TARGET).a: lib$(TARGET).o
	$(AR) rcs $@ $<
lib$(TARGET).so: lib$(TARGET).o lib$(TARGET).h
	$(CC) -shared -fPIC $< -o $@
unit: unit.c libforth.a
	$(CC) $(CFLAGS) $^ -o $@
$(TARGET): main.c lib$(TARGET).a
	$(CC) $(CFLAGS) $^ -o $@

run: $(TARGET)
	./$^
test: unit
	./$^

clean:
	rm -rf $(TARGET) unit *.a *.so *.o *.log *.htm doxygen

