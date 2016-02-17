/* blink.c - CHIP program to blink status light and shut down when XIO-P7 is grounded. */
/*
 * This code and its documentation is Copyright 2016 Steven Ford, http://geeky-boy.com
 * and licensed "public domain" style under Creative Commons "CC0": http://creativecommons.org/publicdomain/zero/1.0/
 * To the extent possible under law, the contributors to this project have
 * waived all copyright and related or neighboring rights to this work.
 * In other words, you can use this code for any purpose without any
 * restrictions.  This work is published from: United States. The project home
 * is https://github.com/fordsfords/blink/tree/gh-pages
 */
#include <fcntl.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

/* See http://wiki.geeky-boy.com/w/index.php?title=Internal_error_handling */
#define WCHK(cond_expr) do { \
  if (!(cond_expr)) { \
    fprintf(stderr, "%s:%d, Warning, expected '%s' to be true (%s)\n", \
      __FILE__, __LINE__, #cond_expr, strerror(errno)); \
  }  \
} while (0)

#define ECHK(cond_expr) do { \
  if (!(cond_expr)) { \
    fprintf(stderr, "%s:%d, Error, expected '%s' to be true (%s)\n", \
      __FILE__, __LINE__, #cond_expr, strerror(errno)); \
    abort(); \
  }  \
} while (0)

 
int main()
{
  /* Store this process's PID to allow easy killing. */
  FILE *pid_file = fopen("/tmp/blink.pid", "w");  ECHK(pid_file != NULL);
  fprintf(pid_file, "%ld\n", (long)getpid());
  fclose(pid_file);

  /* Enable and configure XIO-P7 as input. */

  int exp_fd = open("/sys/class/gpio/export", O_WRONLY);  ECHK(exp_fd != -1);
  /* If port 7 is already exported, the following will fail. That's OK, but warn. */
  int wlen = write(exp_fd, "415", 4);  WCHK(wlen == 4);
  close(exp_fd);
 
  int dir_fd = open("/sys/class/gpio/gpio415/direction", O_RDWR);  ECHK(dir_fd != -1);
  wlen = write(dir_fd, "in", 3);  ECHK(wlen == 3);
  close(dir_fd);

  int led = 0;
  char readbuf[99] = "";
  do {  /* while readbuf */
    if (led) {
      int status = system("/usr/sbin/i2cset -f -y 0 0x34 0x93 0x1");  ECHK(status == 0);
    } else {
      int status = system("/usr/sbin/i2cset -f -y 0 0x34 0x93 0x0");  ECHK(status == 0);
    }
    led = ! led;

    int val_fd = open("/sys/class/gpio/gpio415/value", O_RDWR);  ECHK(val_fd != -1);
    int rlen = read(val_fd, readbuf, sizeof(readbuf));  ECHK(rlen > 0);
    close(val_fd);
    usleep(1000000);  /* 1 million microseconds - 1 second of sleep */
  } while (readbuf[0] == '1');

  exp_fd = open("/sys/class/gpio/unexport", O_WRONLY);  ECHK(exp_fd != -1);
  wlen = write(exp_fd, "415", 4);  ECHK(wlen == 4);
  close(exp_fd);

  int status = system("/sbin/shutdown now");  ECHK(status == 0);
  sleep(5);

  return 0;
}  /* main */
