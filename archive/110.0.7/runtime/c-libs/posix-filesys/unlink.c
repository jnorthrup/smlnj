/* unlink.c
 *
 * COPYRIGHT (c) 1995 by AT&T Bell Laboratories.
 */

#include "ml-unixdep.h"
#include <unistd.h>
#include "ml-base.h"
#include "ml-values.h"
#include "ml-objects.h"
#include "ml-c.h"
#include "cfun-proto-list.h"


/* _ml_P_FileSys_unlink : string -> unit
 *
 * Remove directory entry
 */
ml_val_t _ml_P_FileSys_unlink (ml_state_t *msp, ml_val_t arg)
{
    int		sts;

    sts = unlink(PTR_MLtoC(char, arg));

    CHK_RETURN_UNIT(msp, sts)

} /* end of _ml_P_FileSys_unlink */
