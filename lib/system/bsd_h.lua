local ffi = require("ffi")
require("system/posix_h")

ffi.cdef[[
static const int PATH_MAX = 1024;

/* errno */
static const int EPERM           = 1;
static const int ENOENT          = 2;
static const int ESRCH           = 3;
static const int EINTR           = 4;
static const int EIO             = 5;
static const int ENXIO           = 6;
static const int E2BIG           = 7;
static const int ENOEXEC         = 8;
static const int EBADF           = 9;
static const int ECHILD          = 10;
static const int EDEADLK         = 11;
static const int EDEADLOCK       = EDEADLK;
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
static const int EAGAIN          = 35;
static const int EWOULDBLOCK     = EAGAIN;
static const int EINPROGRESS     = 36;
static const int EALREADY        = 37;
static const int ENOTSOCK        = 38;
static const int EDESTADDRREQ    = 39;
static const int EMSGSIZE        = 40;
static const int EPROTOTYPE      = 41;
static const int ENOPROTOOPT     = 42;
static const int EPROTONOSUPPORT = 43;
static const int ESOCKTNOSUPPORT = 44;
static const int ENOTSUPP        = 45;
static const int EPFNOSUPPORT    = 46;
static const int EAFNOSUPPORT    = 47;
static const int EADDRINUSE      = 48;
static const int EADDRNOTAVAIL   = 49;
static const int ENETDOWN        = 50;
static const int ENETUNREACH     = 51;
static const int ENETRESET       = 52;
static const int ECONNABORTED    = 53;
static const int ECONNRESET      = 54;
static const int ENOBUFS         = 55;
static const int EISCONN         = 56;
static const int ENOTCONN        = 57;
static const int ESHUTDOWN       = 58;
static const int ETOOMANYREFS    = 59;
static const int ETIMEDOUT       = 60;
static const int ECONNREFUSED    = 61;
static const int ELOOP           = 62;
static const int ENAMETOOLONG    = 63;
static const int EHOSTDOWN       = 64;
static const int EHOSTUNREACH    = 65;
static const int ENOTEMPTY       = 66;
static const int EPROCLIM        = 67;
static const int EUSERS          = 68;
static const int EDQUOT          = 69;
static const int ESTALE          = 70;
static const int EREMOTE         = 71;
static const int EBADRPC         = 72;
static const int ERPCMISMATCH    = 73;
static const int EPROGUNAVAIL    = 74;
static const int EPROGMISMATCH   = 75;
static const int EPROCUNAVAIL    = 76;
static const int ENOLCK          = 77;
static const int ENOSYS          = 78;
static const int EFTYPE          = 79;
static const int EAUTH           = 80;
static const int ENEEDAUTH       = 81;
static const int EPWROFF         = 82;
static const int EDEVERR         = 83;
static const int EOVERFLOW       = 84;
static const int EBADEXEC        = 85;
static const int EBADARCH        = 86;
static const int ESHLIBVERS      = 87;
static const int EBADMACHO       = 88;
static const int EIDRM           = 90;
static const int ENOMSG          = 91;
static const int EILSEQ          = 92;
static const int ENOATTR         = 93;
static const int EBADMSG         = 94;
static const int EMULTIHOP       = 95;
static const int ENODATA         = 96;
static const int ENOLINK         = 97;
static const int ENOSR           = 98;
static const int ENOSTR          = 99;
static const int EPROTO          = 100;
static const int ETIME           = 101;
static const int EOPNOTSUPP      = 102;
static const int ENOPOLICY       = 103;
static const int ENOTRECOVERABLE = 104;
static const int EOWNERDEAD      = 105;

/* fcntl */
static const int F_DUPFD = 0;
static const int F_GETFD = 1;
static const int F_SETFD = 2;
static const int F_GETFL = 3;
static const int F_SETFL = 4;
 
static const int O_RDONLY   = 0x0000;
static const int O_RDWR     = 0x0002;
static const int O_NONBLOCK = 0x0004;
static const int O_APPEND   = 0x0008;
static const int O_CREAT    = 0x0200;
static const int O_TRUNC    = 0x0400;

/* poll */
static const int POLLIN          = 0x001;
static const int POLLPRI         = 0x002;
static const int POLLOUT         = 0x004;
static const int POLLWRNORM      = 0x004;
static const int POLLERR         = 0x008;
static const int POLLHUP         = 0x010;
static const int POLLNVAL        = 0x020;
static const int POLLRDNORM      = 0x040;
static const int POLLRDBAND      = 0x080;
static const int POLLWRBAND      = 0x100;
static const int POLLEXTEND      = 0x200;
static const int POLLATTRIB      = 0x400;
static const int POLLNLINK       = 0x800;
static const int POLLWRITE       = 0x1000;

/* mmap */
static const int PROT_NONE  = 0x0;
static const int PROT_READ  = 0x1;
static const int PROT_WRITE = 0x2;
static const int PROT_EXEC  = 0x4;

static const int MAP_FILE           = 0x0000;
static const int MAP_SHARED         = 0x0001;
static const int MAP_PRIVATE        = 0x0002;
static const int MAP_FIXED          = 0x0010;
static const int MAP_RENAME         = 0x0020;
static const int MAP_NORESERVE      = 0x0040;
static const int MAP_NOEXTEND       = 0x0100;
static const int MAP_HASSEMAPHORE   = 0x0200;
static const int MAP_NOCACHE        = 0x0400;
static const int MAP_JIT            = 0x0800;
static const int MAP_ANON           = 0x1000;

struct statvfs {
  unsigned long   f_bsize;
  unsigned long   f_frsize;
  unsigned int    f_blocks;
  unsigned int    f_bfree;
  unsigned int    f_bavail;
  unsigned int    f_files;
  unsigned int    f_ffree;
  unsigned int    f_favail;
  unsigned long   f_fsid;
  unsigned long   f_flag;
  unsigned long   f_namemax;
};

struct addrinfo {
   int ai_flags;
   int ai_family;
   int ai_socktype;
   int ai_protocol;
   socklen_t ai_addrlen;
   char *ai_canonname;
   struct sockaddr *ai_addr;
   struct addrinfo *ai_next;
};

struct sockaddr {
  uint8_t     sa_len;
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
  uint8_t        sa_len;
  sa_family_t    sin_family;
  in_port_t      sin_port;
  struct in_addr sin_addr;
  unsigned char  sin_zero[8];
};

struct sockaddr_in6 {
  uint8_t         sa_len;
  sa_family_t     sin6_family;
  in_port_t       sin6_port;
  uint32_t        sin6_flowinfo;
  struct in6_addr sin6_addr;
  uint32_t        sin6_scope_id;
};

struct sockaddr_un {
  uint8_t     sa_len;
  sa_family_t sun_family;
  char        sun_path[104];
};

]]

