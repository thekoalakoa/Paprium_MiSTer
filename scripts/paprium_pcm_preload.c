/*
 * paprium_pcm_preload — one-shot full paprium.pcm → DDR for Paprium_MiSTer
 *
 * B Jam choice: FULL preload (NOT on-demand, NOT shrink/split).
 *
 * Address contract (must match MegaDrive.sv PAPRIUM_PCM_BASE):
 *   Physical DDR base = 0x10000000
 *   Expected size     ≈ 569,380,864 bytes (~543 MiB)
 *   End               ≈ 0x31F0C400
 *
 * Why not 0x20000000 / fpga_mem?
 *   Main_MiSTer fpga_mem(x) = 0x20000000 | (x & 0x1FFFFFFF) is a 512 MiB
 *   window. paprium.pcm is ~31 MiB larger than that window, and stock HPS
 *   fast-load rejects anything outside [0x20000000, 0x40000000).
 *   mem= does NOT enlarge fpga_mem; it only keeps Linux off the physical
 *   pages so this tool can mmap the true DDR base directly via /dev/mem.
 *
 * Boot (required on DE10):
 *   mem=256M memmap=768M$256M
 *   + thekoalakoa/Main_MiSTer with FB_ADDR moved to 0x32000000
 *     (stock FB at 0x22000000 sits inside the PCM span).
 *
 * Build on MiSTer (or cross):
 *   gcc -O2 -Wall -o paprium_pcm_preload paprium_pcm_preload.c
 *
 * Usage:
 *   ./paprium_pcm_preload [/path/to/paprium.pcm]
 * Default path: /media/fat/games/MegaDrive/Paprium/paprium.pcm
 */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#define PAPRIUM_PCM_BASE      0x10000000u
#define PAPRIUM_PCM_MAX       0x22000000u  /* 544 MiB hard ceiling before FB */
#define PAPRIUM_PCM_EXPECT    569380864ull /* shipping PPAD size */
#define DEFAULT_PCM_PATH      "/media/fat/games/MegaDrive/Paprium/paprium.pcm"
#define CHUNK                 (1024u * 1024u)

static void usage(const char *argv0)
{
	fprintf(stderr,
		"Usage: %s [paprium.pcm]\n"
		"  mmap physical DDR @ 0x%08X and copy the full PPAD blob.\n"
		"  Requires mem=256M memmap=768M$256M and FB @ 0x32000000.\n",
		argv0, PAPRIUM_PCM_BASE);
}

int main(int argc, char **argv)
{
	const char *path = DEFAULT_PCM_PATH;
	if (argc >= 2) {
		if (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help")) {
			usage(argv[0]);
			return 0;
		}
		path = argv[1];
	}

	int fd = open(path, O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "open(%s): %s\n", path, strerror(errno));
		return 1;
	}

	struct stat st;
	if (fstat(fd, &st) < 0) {
		fprintf(stderr, "fstat: %s\n", strerror(errno));
		close(fd);
		return 1;
	}

	uint64_t size = (uint64_t)st.st_size;
	if (size < 0x1000) {
		fprintf(stderr, "file too small (%llu) — need PPAD header\n",
			(unsigned long long)size);
		close(fd);
		return 1;
	}
	if (size > PAPRIUM_PCM_MAX) {
		fprintf(stderr,
			"file too large (%llu) — max %u to stay below FB @ 0x32000000\n",
			(unsigned long long)size, PAPRIUM_PCM_MAX);
		close(fd);
		return 1;
	}
	if (size != PAPRIUM_PCM_EXPECT) {
		fprintf(stderr,
			"warning: size %llu != shipping %llu (continuing)\n",
			(unsigned long long)size,
			(unsigned long long)PAPRIUM_PCM_EXPECT);
	}

	/* Peek magic */
	uint8_t mag[4];
	if (read(fd, mag, 4) != 4 || memcmp(mag, "PPAD", 4) != 0) {
		fprintf(stderr, "bad magic (want PPAD)\n");
		close(fd);
		return 1;
	}
	if (lseek(fd, 0, SEEK_SET) < 0) {
		fprintf(stderr, "lseek: %s\n", strerror(errno));
		close(fd);
		return 1;
	}

	int memfd = open("/dev/mem", O_RDWR | O_SYNC | O_CLOEXEC);
	if (memfd < 0) {
		fprintf(stderr, "open(/dev/mem): %s (need root)\n", strerror(errno));
		close(fd);
		return 1;
	}

	/* Direct physical map — do NOT use fpga_mem(); base < 0x20000000. */
	void *dst = mmap(NULL, (size_t)size, PROT_READ | PROT_WRITE, MAP_SHARED,
			 memfd, PAPRIUM_PCM_BASE);
	if (dst == MAP_FAILED) {
		fprintf(stderr, "mmap(0x%08X, %llu): %s\n",
			PAPRIUM_PCM_BASE, (unsigned long long)size, strerror(errno));
		fprintf(stderr,
			"hint: confirm cmdline has mem=256M memmap=768M$256M\n");
		close(memfd);
		close(fd);
		return 1;
	}

	printf("Paprium PCM preload: %s → DDR 0x%08X (%llu bytes)\n",
	       path, PAPRIUM_PCM_BASE, (unsigned long long)size);

	uint8_t *out = (uint8_t *)dst;
	uint64_t done = 0;
	uint8_t *buf = malloc(CHUNK);
	if (!buf) {
		fprintf(stderr, "OOM\n");
		munmap(dst, (size_t)size);
		close(memfd);
		close(fd);
		return 1;
	}

	while (done < size) {
		size_t want = (size - done > CHUNK) ? CHUNK : (size_t)(size - done);
		ssize_t n = read(fd, buf, want);
		if (n <= 0) {
			fprintf(stderr, "read @ %llu: %s\n",
				(unsigned long long)done,
				n < 0 ? strerror(errno) : "EOF");
			free(buf);
			munmap(dst, (size_t)size);
			close(memfd);
			close(fd);
			return 1;
		}
		memcpy(out + done, buf, (size_t)n);
		done += (uint64_t)n;
		if ((done & ((16ull * CHUNK) - 1)) == 0 || done == size) {
			unsigned pct = (unsigned)((done * 100ull) / size);
			printf("\r  %3u%%  %llu / %llu", pct,
			       (unsigned long long)done,
			       (unsigned long long)size);
			fflush(stdout);
		}
	}
	printf("\n");

	/* Sanity: magic visible in DDR */
	if (memcmp(out, "PPAD", 4) != 0) {
		fprintf(stderr, "verify failed: DDR magic not PPAD\n");
		free(buf);
		munmap(dst, (size_t)size);
		close(memfd);
		close(fd);
		return 1;
	}

	free(buf);
	munmap(dst, (size_t)size);
	close(memfd);
	close(fd);

	printf("OK — full paprium.pcm resident at 0x%08X for FPGA fetch RTL\n",
	       PAPRIUM_PCM_BASE);
	return 0;
}
