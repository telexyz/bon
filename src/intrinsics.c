#include <stdint.h>
#include <x86intrin.h>

unsigned int __pext_u32(unsigned int x, unsigned int y){
	return _pext_u32(x, y);
}