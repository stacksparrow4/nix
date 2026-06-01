#!/usr/bin/env python3
import os
import threading
import errno
import stat

from fuse import FUSE, FuseOSError, Operations


class NixOverlay(Operations):
    def __init__(self, lower, upper, ready_event):
        self.lower = os.path.realpath(lower)
        self.upper = os.path.realpath(upper)
        self.ready_event = ready_event

    def init(self, path):
        self.ready_event.set()

    def _lower(self, path):
        return os.path.join(self.lower, path.lstrip("/"))

    def _upper(self, path):
        return os.path.join(self.upper, path.lstrip("/"))

    def _which(self, path):
        """Return (real_path, layer) where layer is 'upper', 'lower', or None."""
        up = self._upper(path)
        if os.path.lexists(up):
            return up, "upper"
        lo = self._lower(path)
        if os.path.lexists(lo):
            return lo, "lower"
        return None, None

    def _ensure_parent(self, path):
        up = self._upper(path)
        parent = os.path.dirname(up)
        os.makedirs(parent, exist_ok=True)

    def _copy_up(self, path):
        """Copy a file/dir/symlink from lower to upper."""
        up = self._upper(path)
        if os.path.lexists(up):
            return
        lo = self._lower(path)
        st = os.lstat(lo)
        self._ensure_parent(path)

        if stat.S_ISDIR(st.st_mode):
            os.makedirs(up, mode=st.st_mode | 0o700, exist_ok=True)
        elif stat.S_ISLNK(st.st_mode):
            target = os.readlink(lo)
            os.symlink(target, up)
        elif stat.S_ISREG(st.st_mode):
            with open(lo, "rb") as fin, open(up, "wb") as fout:
                while True:
                    buf = fin.read(65536)
                    if not buf:
                        break
                    fout.write(buf)
            os.chmod(up, st.st_mode)
        else:
            raise FuseOSError(errno.ENOSYS)

    # -- Filesystem operations --

    def getattr(self, path, fh=None):
        real, layer = self._which(path)
        if real is None:
            raise FuseOSError(errno.ENOENT)
        st = os.lstat(real)
        attrs = {
            key: getattr(st, key)
            for key in (
                "st_atime",
                "st_ctime",
                "st_gid",
                "st_mode",
                "st_mtime",
                "st_nlink",
                "st_size",
                "st_uid",
                "st_blocks",
                "st_blksize",
            )
            if hasattr(st, key)
        }
        # Report directories as owner-writable so FUSE 3's
        # default_permissions never blocks writes through the overlay.
        if stat.S_ISDIR(attrs["st_mode"]):
            attrs["st_mode"] |= 0o700
        return attrs

    def readlink(self, path):
        real, layer = self._which(path)
        if real is None:
            raise FuseOSError(errno.ENOENT)
        return os.readlink(real)

    def readdir(self, path, fh):
        entries = set()
        for base in (self._upper(path), self._lower(path)):
            try:
                entries.update(os.listdir(base))
            except OSError:
                pass
        return [".", ".."] + list(entries)

    def open(self, path, flags):
        real, layer = self._which(path)
        if real is None:
            raise FuseOSError(errno.ENOENT)
        if (flags & os.O_ACCMODE) != os.O_RDONLY and layer == "lower":
            self._copy_up(path)
            real = self._upper(path)
        fd = os.open(real, flags)
        return fd

    def read(self, path, size, offset, fh):
        return os.pread(fh, size, offset)

    def write(self, path, data, offset, fh):
        return os.pwrite(fh, data, offset)

    def release(self, path, fh):
        os.close(fh)

    def create(self, path, mode, fi=None):
        self._ensure_parent(path)
        up = self._upper(path)
        fd = os.open(up, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
        return fd

    def mkdir(self, path, mode):
        self._ensure_parent(path)
        os.mkdir(self._upper(path), mode | 0o700)

    def unlink(self, path):
        up = self._upper(path)
        if os.path.lexists(up):
            os.unlink(up)
        else:
            raise FuseOSError(errno.ENOENT)

    def rmdir(self, path):
        os.rmdir(self._upper(path))

    def symlink(self, target, source):
        # fusepy argument names are misleading!
        #   target = path of the new symlink (on the FUSE mount)
        #   source = what the symlink points to (link contents)
        self._ensure_parent(target)
        os.symlink(source, self._upper(target))

    def rename(self, old, new):
        up_old = self._upper(old)
        if not os.path.lexists(up_old):
            self._copy_up(old)
        self._ensure_parent(new)
        os.rename(up_old, self._upper(new))

    def link(self, target, source):
        # fusepy: target = new link path, source = existing file path
        up_source = self._upper(source)
        if not os.path.lexists(up_source):
            self._copy_up(source)
        self._ensure_parent(target)
        os.link(up_source, self._upper(target))

    def chmod(self, path, mode):
        up = self._upper(path)
        if not os.path.lexists(up):
            self._copy_up(path)
        # Keep directories writable in the upper layer.
        st = os.lstat(up)
        if stat.S_ISDIR(st.st_mode):
            mode |= 0o700
        os.chmod(up, mode)

    def chown(self, path, uid, gid):
        up = self._upper(path)
        if not os.path.lexists(up):
            self._copy_up(path)
        os.lchown(up, uid, gid)

    def truncate(self, path, length, fh=None):
        up = self._upper(path)
        if not os.path.lexists(up):
            self._copy_up(path)
        with open(up, "r+b") as f:
            f.truncate(length)

    def utimens(self, path, times=None):
        real, layer = self._which(path)
        if real is None:
            raise FuseOSError(errno.ENOENT)
        if layer == "lower":
            return
        os.utime(real, times, follow_symlinks=False)

    def access(self, path, amode):
        real, layer = self._which(path)
        if real is None:
            raise FuseOSError(errno.ENOENT)
        if not os.access(real, amode):
            raise FuseOSError(errno.EACCES)

    def statfs(self, path):
        st = os.statvfs(self.upper)
        return {
            key: getattr(st, key)
            for key in (
                "f_bavail",
                "f_bfree",
                "f_blocks",
                "f_bsize",
                "f_favail",
                "f_ffree",
                "f_files",
                "f_flag",
                "f_frsize",
                "f_namemax",
            )
        }

    def getxattr(self, path, name, position=0):
        real, layer = self._which(path)
        if real is None:
            raise FuseOSError(errno.ENOENT)
        try:
            return os.getxattr(real, name, follow_symlinks=False)
        except OSError as e:
            raise FuseOSError(e.errno)

    def listxattr(self, path):
        real, layer = self._which(path)
        if real is None:
            raise FuseOSError(errno.ENOENT)
        try:
            return os.listxattr(real, follow_symlinks=False)
        except OSError as e:
            raise FuseOSError(e.errno)

    def mknod(self, path, mode, dev):
        self._ensure_parent(path)
        os.mknod(self._upper(path), mode, dev)


def start_overlay(lower, upper, mountpoint):
    ready = threading.Event()

    t = threading.Thread(
        target=FUSE,
        args=(NixOverlay(lower, upper, ready), mountpoint),
        kwargs={"foreground": True},
    )
    t.daemon = True
    t.start()

    ready.wait()
