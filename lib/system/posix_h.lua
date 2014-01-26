local ffi = require("ffi")
ffi.cdef[[
typedef long unsigned int size_t;
typedef long int ssize_t;
typedef long int off_t;

typedef uint16_t in_port_t;
typedef uint32_t socklen_t;
typedef uint8_t sa_family_t;

struct timeval {
  long int tv_sec;
  long int tv_usec;
};

struct statvfs;
int statvfs(const char *restrict, struct statvfs *restrict);

int pipe(int *);
int fork(void);
int dup(int);
int dup2(int, int);

int open(const char *, int, ...);
int close(int);
int fcntl(int, int, ...);
int execl(const char *, const char *, ...);
int execlp(const char *, const char *, ...);
int execv(const char *, char *const *);
int execvp(const char *, char *const *);
long int write(int, const void *, long unsigned int);
long int read(int, void *, long unsigned int);
int kill(int, int);
int waitpid(int, int *, int);

void *mmap(void *, long unsigned int, int, int, int, long int);

int ioctl(int, long unsigned int, ...);
unsigned int sleep(unsigned int);
int usleep(unsigned int);
int gettimeofday(struct timeval *restrict, struct timezone *restrict);
char *realpath(const char *restrict, char *restrict);

void *malloc(long unsigned int);
void free(void *);

char *strdup(const char *);
char *strndup(const char *, long unsigned int);

struct _IO_FILE *fopen(const char *restrict, const char *restrict);
int fclose(struct _IO_FILE *);
int printf(const char *, ...);
int sprintf(char *, const char *, ...);
int fprintf(struct _IO_FILE *restrict, const char *restrict, ...);
int fputc(int, struct _IO_FILE *);
char *strerror(int);

struct addrinfo;
struct sockaddr;

int socket(int domain, int type, int protocol);
int socketpair(int domain, int type, int protocol, int sv[2]);
int bind(int sockfd, struct sockaddr *addr, socklen_t addrlen);
int listen(int sockfd, int backlog);
int connect(int sockfd, struct sockaddr *addr, socklen_t addrlen);
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
int accept4(int sockfd, struct sockaddr *addr, socklen_t *addrlen, int flags);
int getsockname(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
int getpeername(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
int shutdown(int sockfd, int how);

typedef struct fd_set {
   int32_t fds_bits[32];
} fd_set;

int select(int nfds, fd_set *rfds, fd_set *wfds, fd_set *efds,
   struct timeval *timeout);

int getsockopt(int socket, int level, int option_name,
   void *option_value, socklen_t *option_len);

int setsockopt(int socket, int level, int option_name,
   const void *option_value, socklen_t option_len);

int getaddrinfo(const char *host, const char *port, struct addrinfo *hints, struct addrinfo **res);
void freeaddrinfo(struct addrinfo *ai);

struct pollfd {
  int fd;
  short int events;
  short int revents;
};

int poll(struct pollfd *, long unsigned int, int);
]]
