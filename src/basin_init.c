#include "basin.h"
#include <stdlib.h>
#include <string.h>

static BasinConfig g_cfg;
static int g_initialized = 0;

int basin_init(BasinConfig* cfg) {
    if (!cfg) return -1;
    
    memcpy(&g_cfg, cfg, sizeof(BasinConfig));
    g_initialized = 1;
    return 0;
}

void basin_free(void) {
    g_initialized = 0;
    memset(&g_cfg, 0, sizeof(BasinConfig));
}
