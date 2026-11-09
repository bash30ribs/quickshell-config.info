/*
 * QDeck: Lightweight Wayland/evdev lockstate monitor for keyboard LEDs
 * Single-instance, zero-CPU sysfs polling monitor.
 */
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <glob.h>
#include <string.h>
#include <sys/file.h>

static int open_led(const char *pattern) {
    glob_t g;
    int fd = -1;
    if (glob(pattern, 0, NULL, &g) == 0 && g.gl_pathc > 0) {
        fd = open(g.gl_pathv[0], O_RDONLY);
    }
    globfree(&g);
    return fd;
}

static int read_led_val(int fd) {
    char buf[16];
    if (fd < 0) return -1;
    if (lseek(fd, 0, SEEK_SET) == (off_t)-1) return -1;
    int n = read(fd, buf, sizeof(buf) - 1);
    if (n > 0) {
        if (buf[0] == '1') return 1;
        if (buf[0] == '0') return 0;
    }
    return -1;
}

int main(void) {
    // Single instance lock to prevent orphan stacking on QuickShell reload
    int lock_fd = open("/tmp/qdeck-lockstate.lock", O_CREAT | O_RDWR, 0666);
    if (lock_fd >= 0) {
        if (flock(lock_fd, LOCK_EX | LOCK_NB) != 0) {
            // Another instance is already running
            close(lock_fd);
            return 0;
        }
    }

    int num_fd = open_led("/sys/class/leds/*numlock*/brightness");
    int caps_fd = open_led("/sys/class/leds/*capslock*/brightness");

    int last_num = read_led_val(num_fd);
    int last_caps = read_led_val(caps_fd);

    while (1) {
        // Sleep 80ms: responsive keyboard LED tracking with strictly 0.0% CPU
        usleep(80000);

        if (num_fd < 0) {
            num_fd = open_led("/sys/class/leds/*numlock*/brightness");
            last_num = read_led_val(num_fd);
        }

        if (caps_fd < 0) {
            caps_fd = open_led("/sys/class/leds/*capslock*/brightness");
            last_caps = read_led_val(caps_fd);
        }

        if (num_fd >= 0) {
            int cur_num = read_led_val(num_fd);
            if (cur_num >= 0 && cur_num != last_num) {
                last_num = cur_num;
                printf("NUMLOCK:%s\n", cur_num ? "ON" : "OFF");
                fflush(stdout);
            }
        }

        if (caps_fd >= 0) {
            int cur_caps = read_led_val(caps_fd);
            if (cur_caps >= 0 && cur_caps != last_caps) {
                last_caps = cur_caps;
                printf("CAPSLOCK:%s\n", cur_caps ? "ON" : "OFF");
                fflush(stdout);
            }
        }
    }

    if (num_fd >= 0) close(num_fd);
    if (caps_fd >= 0) close(caps_fd);
    if (lock_fd >= 0) close(lock_fd);
    return 0;
}
