/* mkfifo.c
 *
 * COPYRIGHT (c) 1995 by AT&T Bell Laboratories.
 */

#include "ml-unixdep.h"
#include <sys/types.h>
#include <sys/stat.h>
#include "ml-base.h"
#include "ml-values.h"
#include "ml-objects.h"
#include "ml-c.h"
#include "cfun-proto-list.h"


/* _ml_P_FileSys_mkfifo : (string * word) -> unit
 *                         name     mode
 *
 * Make a FIFO special file.
 */
ml_val_t _ml_P_FileSys_mkfifo (ml_state_t *msp, ml_val_t arg)
{
    char	    *path = REC_SELPTR(char, arg, 0);
    mode_t	    mode = REC_SELWORD(arg, 1);
    int		    sts;

    sts = mkfifo (path, mode);

    CHK_RETURN_UNIT(msp, sts)

} /* end of _ml_P_FileSys_mkfifo */
