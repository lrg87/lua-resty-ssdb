# vim:set noet:

default: build

.DEFAULT:
	DFLAGS=-DSPP_LIB_PATH=resty_ssdb_spp_lua_spp_lua make $@ -C spp_lua
