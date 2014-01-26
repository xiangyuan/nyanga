local ffi = require("ffi")
require("system/posix_h")

ffi.cdef[[
static const int PATH_MAX = 4096;

/* errno */
static const int EPERM           =  1;
static const int ENOENT          =  2;
static const int ESRCH           =  3;
static const int EINTR           =  4;
static const int EIO             =  5;
static const int ENXIO           =  6;
static const int E2BIG           =  7;
static const int ENOEXEC         =  8;
static const int EBADF           =  9;
static const int ECHILD          = 10;
static const int EAGAIN          = 11;
static const int EWOULDBLOCK     = EAGAIN;
static const int ENOMEM          = 12;
static const int EACCES          = 13;
static const int EFAULT          = 14;
static const int ENOTBLK         = 15;
static const int EBUSY           = 16;
static const int EEXIST          = 17;
static const int EXDEV           = 18;
static const int ENODEV          = 19;
static const int ENOTDIR         = 20;
static const int EISDIR          = 21;
static const int EINVAL          = 22;
static const int ENFILE          = 23;
static const int EMFILE          = 24;
static const int ENOTTY          = 25;
static const int ETXTBSY         = 26;
static const int EFBIG           = 27;
static const int ENOSPC          = 28;
static const int ESPIPE          = 29;
static const int EROFS           = 30;
static const int EMLINK          = 31;
static const int EPIPE           = 32;
static const int EDOM            = 33;
static const int ERANGE          = 34;
static const int EDEADLK         = 35;
static const int ENAMETOOLONG    = 36;
static const int ENOLCK          = 37;
static const int ENOSYS          = 38;
static const int ENOTEMPTY       = 39;
static const int ELOOP           = 40;
static const int ENOMSG          = 42;
static const int EIDRM           = 43;
static const int ECHRNG          = 44;
static const int EL2NSYNC        = 45;
static const int EL3HLT          = 46;
static const int EL3RST          = 47;
static const int ELNRNG          = 48;
static const int EUNATCH         = 49;
static const int ENOCSI          = 50;
static const int EL2HLT          = 51;
static const int EBADE           = 52;
static const int EBADR           = 53;
static const int EXFULL          = 54;
static const int ENOANO          = 55;
static const int EBADRQC         = 56;
static const int EBADSLT         = 57;
static const int EBFONT          = 59;
static const int ENOSTR          = 60;
static const int ENODATA         = 61;
static const int ETIME           = 62;
static const int ENOSR           = 63;
static const int ENONET          = 64;
static const int ENOPKG          = 65;
static const int EREMOTE         = 66;
static const int ENOLINK         = 67;
static const int EADV            = 68;
static const int ESRMNT          = 69;
static const int ECOMM           = 70;
static const int EPROTO          = 71;
static const int EMULTIHOP       = 72;
static const int EDOTDOT         = 73;
static const int EBADMSG         = 74;
static const int EOVERFLOW       = 75;
static const int ENOTUNIQ        = 76;
static const int EBADFD          = 77;
static const int EREMCHG         = 78;
static const int ELIBACC         = 79;
static const int ELIBBAD         = 80;
static const int ELIBSCN         = 81;
static const int ELIBMAX         = 82;
static const int ELIBEXEC        = 83;
static const int EILSEQ          = 84;
static const int ERESTART        = 85;
static const int ESTRPIPE        = 86;
static const int EUSERS          = 87;
static const int ENOTSOCK        = 88;
static const int EDESTADDRREQ    = 89;
static const int EMSGSIZE        = 90;
static const int EPROTOTYPE      = 91;
static const int ENOPROTOOPT     = 92;
static const int EPROTONOSUPPORT = 93;
static const int ESOCKTNOSUPPORT = 94;
static const int EOPNOTSUPP      = 95;
static const int EPFNOSUPPORT    = 96;
static const int EAFNOSUPPORT    = 97;
static const int EADDRINUSE      = 98;
static const int EADDRNOTAVAIL   = 99;
static const int ENETDOWN        = 100;
static const int ENETUNREACH     = 101;
static const int ENETRESET       = 102;
static const int ECONNABORTED    = 103;
static const int ECONNRESET      = 104;
static const int ENOBUFS         = 105;
static const int EISCONN         = 106;
static const int ENOTCONN        = 107;
static const int ESHUTDOWN       = 108;
static const int ETOOMANYREFS    = 109;
static const int ETIMEDOUT       = 110;
static const int ECONNREFUSED    = 111;
static const int EHOSTDOWN       = 112;
static const int EHOSTUNREACH    = 113;
static const int EALREADY        = 114;
static const int EINPROGRESS     = 115;
static const int ESTALE          = 116;
static const int EUCLEAN         = 117;
static const int ENOTNAM         = 118;
static const int ENAVAIL         = 119;
static const int EISNAM          = 120;
static const int EREMOTEIO       = 121;
static const int EDQUOT          = 122;
static const int ENOMEDIUM       = 123;
static const int EMEDIUMTYPE     = 124;
static const int ECANCELED       = 125;
static const int ENOKEY          = 126;
static const int EKEYEXPIRED     = 127;
static const int EKEYREVOKED     = 128;
static const int EKEYREJECTED    = 129;
static const int EOWNERDEAD      = 130;
static const int ENOTRECOVERABLE = 131;
static const int ERFKILL         = 132;

/* fcntl */
static const int F_DUPFD = 0;
static const int F_GETFD = 1;
static const int F_SETFD = 2;
static const int F_GETFL = 3;
static const int F_SETFL = 4;
 
static const int O_RDONLY   = 0x0000;
static const int O_RDWR     = 0x0002;
static const int O_CREAT    = 0x0040;
static const int O_TRUNC    = 0x0200;
static const int O_APPEND   = 0x0400;
static const int O_NONBLOCK = 0x0800;

/* poll */
static const int POLLIN          = 0x001;
static const int POLLPRI         = 0x002;
static const int POLLOUT         = 0x004;
static const int POLLERR         = 0x008;
static const int POLLHUP         = 0x010;
static const int POLLNVAL        = 0x020;
static const int POLLRDNORM      = 0x040;
static const int POLLRDBAND      = 0x080;
static const int POLLWRNORM      = 0x100;
static const int POLLWRBAND      = 0x200;
static const int POLLMSG         = 0x400;
static const int POLLREMOVE      = 0x1000;
static const int POLLRDHUP       = 0x2000;

/* mmap */
static const int PROT_NONE      = 0x0;
static const int PROT_READ      = 0x1;
static const int PROT_WRITE     = 0x2;
static const int PROT_EXEC      = 0x4;
static const int PROT_GROWSDOWN = 0x01000000;
static const int PROT_GROWSUP   = 0x02000000;

static const int MAP_FILE       = 0;
static const int MAP_SHARED     = 0x01;
static const int MAP_PRIVATE    = 0x02;
static const int MAP_TYPE       = 0x0f;
static const int MAP_FIXED      = 0x10;
static const int MAP_ANON       = 0x20;
static const int MAP_GROWSDOWN  = 0x00100;
static const int MAP_DENYWRITE  = 0x00800;
static const int MAP_EXECUTABLE = 0x01000;
static const int MAP_LOCKED     = 0x02000;
static const int MAP_NORESERVE  = 0x04000;
static const int MAP_POPULATE   = 0x08000;
static const int MAP_NONBLOCK   = 0x10000;
static const int MAP_STACK      = 0x20000;
static const int MAP_HUGETLB    = 0x40000;

/* stat */
struct statvfs {
  long unsigned int f_bsize;
  long unsigned int f_frsize;
  long unsigned int f_blocks;
  long unsigned int f_bfree;
  long unsigned int f_bavail;
  long unsigned int f_files;
  long unsigned int f_ffree;
  long unsigned int f_favail;
  long unsigned int f_fsid;
  long unsigned int f_flag;
  long unsigned int f_namemax;
  int __f_spare[6];
};

/* sockets */
static const int SOL_SOCKET   = 1;

static const int SO_DEBUG       = 1;
static const int SO_REUSEADDR   = 2;
static const int SO_TYPE        = 3;
static const int SO_ERROR       = 4;
static const int SO_DONTROUTE   = 5;
static const int SO_BROADCAST   = 6;
static const int SO_SNDBUF      = 7;
static const int SO_RCVBUF      = 8;
static const int SO_KEEPALIVE   = 9;
static const int SO_OOBINLINE   = 10;
static const int SO_LINGER      = 13;
static const int SO_REUSEPORT   = 15;
static const int SO_RCVLOWAT    = 18;
static const int SO_SNDLOWAT    = 19;
static const int SO_RCVTIMEO    = 20;
static const int SO_SNDTIMEO    = 21;
static const int SO_ACCEPTCONN  = 30;

static const int SOCK_STREAM  = 1;
static const int SOCK_DGRAM   = 2;
static const int SOCK_RAW     = 3;

static const int AF_UNSPEC    = 0;
static const int AF_UNIX      = 1;
static const int AF_INET      = 2;
static const int AF_INET6     = 10;

static const int IPPROTO_TCP  = 6;
static const int IPPROTO_UDP  = 17;

static const int MSG_OOB             = 0x01;
static const int MSG_PEEK            = 0x02;
static const int MSG_DONTROUTE       = 0x04;
static const int MSG_CTRUNC          = 0x08;
static const int MSG_PROXY           = 0x10;
static const int MSG_TRUNC           = 0x20;
static const int MSG_DONTWAIT        = 0x40;
static const int MSG_EOR             = 0x80;
static const int MSG_WAITALL         = 0x100;
static const int MSG_FIN             = 0x200;
static const int MSG_SYN             = 0x400;
static const int MSG_CONFIRM         = 0x800;
static const int MSG_RST             = 0x1000;
static const int MSG_ERRQUEUE        = 0x2000;
static const int MSG_NOSIGNAL        = 0x4000;
static const int MSG_MORE            = 0x8000;
static const int MSG_WAITFORONE      = 0x10000;
static const int MSG_CMSG_CLOEXEC    = 0x40000000;

struct addrinfo {
   int ai_flags;
   int ai_family;
   int ai_socktype;
   int ai_protocol;
   socklen_t ai_addrlen;
   struct sockaddr *ai_addr;
   char *ai_canonname;
   struct addrinfo *ai_next;
};

struct sockaddr {
  sa_family_t sa_family;
  char        sa_data[14];
};

struct in_addr {
  uint32_t       s_addr;
};

struct in6_addr {
  unsigned char  s6_addr[16];
};

struct sockaddr_in {
  sa_family_t    sin_family;
  in_port_t      sin_port;
  struct in_addr sin_addr;
  unsigned char  sin_zero[8];
};

struct sockaddr_in6 {
  sa_family_t     sin6_family;
  in_port_t       sin6_port;
  uint32_t        sin6_flowinfo;
  struct in6_addr sin6_addr;
  uint32_t        sin6_scope_id;
};

struct sockaddr_un {
  sa_family_t sun_family;
  char        sun_path[108];
};

]]
