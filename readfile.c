#define _GNU_SOURCE
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <sys/mman.h>

#define BUFSIZE BUFSIZ
static char buf[BUFSIZE];

static void die(const char *msg) {
	perror(msg);
	exit(EXIT_FAILURE);
}

static void my_mmap(char *path, int advice) {
	int ret;

	int fd = open(path, O_RDONLY);
	struct stat fstats;
	ret = fstat(fd, &fstats);
	if (ret)
		die(path);
	if (!S_ISREG(fstats.st_mode))
		exit(EXIT_FAILURE);

	size_t flen = fstats.st_size;

	char *fmap = mmap(0, flen, PROT_READ, MAP_PRIVATE | MAP_POPULATE, fd, 0);
	if (fmap == MAP_FAILED)
		die(path);

	ret = posix_madvise(fmap, flen, advice);
	if (ret) {
		die(path);
	}

	char *read = fmap;

	while (read <= fmap + flen - sizeof(buf)) {
		memcpy(buf, read, sizeof(buf));
		read += sizeof(buf);
	}
	memcpy(buf, read, fmap + flen - read);
	munmap(fmap, flen);
	close(fd);
}


static void my_fread(char *path, int advice) {
	int ret;
	FILE *f = fopen(path, "r");
	if (!f) {
		die(path);
	}
	//setbuf(f, NULL);
	int fd = fileno(f);
	struct stat fstats;
	ret = fstat(fd, &fstats);
	if (ret)
		die(path);
	if (!S_ISREG(fstats.st_mode))
		exit(EXIT_FAILURE);

	ret = posix_fadvise(fd, 0, 0, advice);
	if (ret)
		die("fadvise");
	//ret = posix_fadvise(fd, 0, 0, POSIX_FADV_SEQUENTIAL);
	if (ret)
		die("fadvise");
	
	for (;;) {
		if (fread_unlocked(buf, 1, BUFSIZE, f) != BUFSIZE) {
			if (feof(f)) {
				fclose(f);
				break;
			} else {
				fclose(f);
				die("couldnt read input file");
			}
		}
	}
}



int main(int args, char **argc) {
	if (args < 4 || args > 4) {
		fprintf(stderr,
			"give 3 cmdline args: filename and readmethod mmap or "
			"fread and the flag part of POSIX_FADV_FLAG\n");
		exit(EXIT_FAILURE);
	}
	int advice;
	int madvice;
	if (args < 4) {
		advice = POSIX_FADV_NORMAL;
		madvice = POSIX_MADV_NORMAL;
	} else if (!strcmp(argc[3], "NOREUSE")) {
		advice = POSIX_FADV_NOREUSE;
		madvice = POSIX_MADV_NORMAL;
	} else if (!strcmp(argc[3], "NORMAL")) {
		advice = POSIX_FADV_NORMAL;
		madvice = POSIX_MADV_NORMAL;
	} else if (!strcmp(argc[3], "SEQUENTIAL")) {
		advice = POSIX_FADV_SEQUENTIAL;
		madvice = POSIX_MADV_SEQUENTIAL;
	} else {
		fprintf(stderr, "3rd argument not supported\n");
		exit(EXIT_FAILURE);
	}
	if (!strcmp(argc[2], "mmap")) {
		my_mmap(argc[1], madvice);
	} else {
		my_fread(argc[1], advice);
	}
	exit(EXIT_SUCCESS);
}
