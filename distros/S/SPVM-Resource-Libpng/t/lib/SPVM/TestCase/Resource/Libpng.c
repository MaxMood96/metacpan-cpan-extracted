#include "spvm_native.h"

#include <png.h>

int32_t SPVM__TestCase__Resource__Libpng__test(SPVM_ENV* env, SPVM_VALUE* stack) {
  
  png_colorp palette;
  
  stack[0].ival = 1;
  
  return 0;
}
