/* ml_signal.h     (MS-Windows version)
 *
 * COPYRIGHT (c) 1990 by AT&T Bell Laboratories.
 *
 * Altered 20 Dec. 1991 by:    Yngvi S. Guttesen
 *                             Department of Computer Science
 *                             The Technical University of Denmark
 *                             DK-2800 Lyngby
 *
 * Signals are not used in the Windows version !
 */

/* #ifndef _ML_SIGNAL_
 *#define _ML_SIGNAL_
 */

/* the ML signal codes (these must agree with the function
 * System.Signals.sig2code in "boot/perv.sml"
 */
#define ML_NOSIG		-1
#define ML_SIGHUP		0
#define ML_SIGINT		1
#define ML_SIGQUIT		2
#define ML_SIGALRM		3
#define ML_SIGTERM		4
#define ML_SIGURG		5
#define ML_SIGCHLD		6
#define ML_SIGIO		7
#define ML_SIGWINCH		8
#define ML_SIGUSR1		9
#define ML_SIGUSR2		10
#define ML_SIGTSTP		11
#define ML_SIGCONT		12
#define ML_SIGGC                13

#define NUM_ML_SIGS		14	/* the number of ML supported signals */

#define SIG_NOT_UNIX		0	/* the code for non-unix signals */

/* the state of ML signal handlers */
#define ML_SIG_DISABLED		0
#define ML_SIG_ENABLED		1

/* #endif */
