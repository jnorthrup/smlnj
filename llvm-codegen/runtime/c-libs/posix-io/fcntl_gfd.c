/* fcntl_gfd.c
 *
 * COPYRIGHT (c) 2019 The Fellowship of SML/NJ (http://www.smlnj.org)
 * All rights reserved.
 */

#include "ml-unixdep.h"
#include <fcntl.h>
#include "ml-objects.h"
#include "ml-c.h"
#include "cfun-proto-list.h"

/* _ml_P_IO_fcntl_gfd : int -> SysWord.word
 *
 * Get the close-on-exec flag associated with the file descriptor.
 */
ml_val_t _ml_P_IO_fcntl_gfd (ml_state_t *msp, ml_val_t arg)
{
    int             flag;
    ml_val_t        v;

    flag = fcntl(INT_MLtoC(arg), F_GETFD);

    if (flag == -1) {
        return RAISE_SYSERR(msp, flag);
    }
    else {
        SYSWORD_ALLOC (msp, v, (SysWord_t)flag);
        return v;
    }

} /* end of _ml_P_IO_fcntl_gfd */
