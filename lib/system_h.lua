local ffi = require("ffi")
if ffi.os == "Linux" then
   require("system/linux_h")
elseif ffi.os == "OSX" then
   require("system/osx_h")
elseif ffi.os == "BSD" then
   require("system/bsd_h")
elseif ffi.os == "POSIX" then
   require("system/posix_h")
else
   error("unsupported platform")
end

