use std::{
    collections::HashMap,
    ffi::{OsStr, OsString},
    fs::{self, File, OpenOptions},
    io::{self, Read},
    os::{
        fd::{AsRawFd, OwnedFd},
        unix::fs::{DirEntryExt, FileExt},
    },
    path::{Path, PathBuf},
    sync::{Mutex, MutexGuard},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use fuser::{
    BackgroundSession, Config, Errno, FileAttr, FileHandle, FileType, Filesystem, FopenFlags,
    Generation, INodeNo, InitFlags, KernelConfig, LockOwner, OpenAccMode, OpenFlags, Owner,
    RenameFlags, ReplyAttr, ReplyCreate, ReplyData, ReplyDirectory, ReplyEmpty, ReplyEntry,
    ReplyOpen, ReplyWrite, Request, TimeOrNow, WriteFlags,
};
use nix::{
    fcntl::{self, AT_FDCWD, AtFlags, OFlag, openat, renameat2},
    sys::stat::{FileStat, Mode, fstat, fstatat, mkdirat},
    unistd::{UnlinkatFlags, unlinkat},
};
use tempfile::{TempDir, tempdir};

pub const NOTE_MAX_BYTES: usize = 300;
pub const DIR_MAX_ENTRIES: usize = 10;
pub const NAME_MAX_BYTES: usize = 40;

const TTL: Duration = Duration::ZERO;
const GENERATION: Generation = Generation(0);

pub struct NotesFs {
    _session: BackgroundSession,
    mountpoint: TempDir,
}

impl NotesFs {
    pub fn mount(dir: &Path) -> Result<NotesFs, String> {
        let root = openat(
            AT_FDCWD,
            dir,
            OFlag::O_PATH | OFlag::O_DIRECTORY | OFlag::O_CLOEXEC,
            Mode::empty(),
        )
        .map_err(|e| format!("Failed to open notes dir {}: {e}", dir.display()))?;
        let st =
            fstat(&root).map_err(|e| format!("Failed to stat notes dir {}: {e}", dir.display()))?;
        let key = (st.st_dev as u64, st.st_ino as u64);

        let state = State {
            inodes: HashMap::from([(
                INodeNo::ROOT.0,
                Inode {
                    fd: root,
                    key,
                    nlookup: 1,
                },
            )]),
            by_key: HashMap::from([(key, INodeNo::ROOT.0)]),
            handles: HashMap::new(),
            next_ino: INodeNo::ROOT.0 + 1,
            next_fh: 1,
        };

        let mountpoint = tempdir().expect("Failed to create notes mountpoint");
        let session = fuser::spawn_mount(
            Notes(Mutex::new(state)),
            mountpoint.path(),
            &Config::default(),
        )
        .map_err(|e| format!("Failed to mount notes filesystem: {e}"))?;

        Ok(NotesFs {
            _session: session,
            mountpoint,
        })
    }

    pub fn path(&self) -> &Path {
        self.mountpoint.path()
    }
}

struct Inode {
    fd: OwnedFd,
    key: (u64, u64),
    nlookup: u64,
}

enum Handle {
    Read(File),
    Write {
        file: File,
        data: Vec<u8>,
        dirty: bool,
        failed: bool,
    },
}

struct State {
    inodes: HashMap<u64, Inode>,
    by_key: HashMap<(u64, u64), u64>,
    handles: HashMap<u64, (u64, Handle)>,
    next_ino: u64,
    next_fh: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, serde::Deserialize)]
#[serde(try_from = "String")]
pub struct NotesName(String);

impl NotesName {
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl TryFrom<String> for NotesName {
    type Error = String;

    fn try_from(name: String) -> Result<Self, Self::Error> {
        if name.is_empty() || !name.chars().all(|c| c.is_ascii_alphanumeric() || c == '-') {
            return Err(format!(
                "Invalid notes name '{name}': must be non-empty and alphanumeric or '-'"
            ));
        }
        Ok(NotesName(name))
    }
}

impl std::str::FromStr for NotesName {
    type Err = String;

    fn from_str(name: &str) -> Result<Self, Self::Err> {
        name.to_string().try_into()
    }
}

impl std::fmt::Display for NotesName {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

fn errno(e: nix::errno::Errno) -> Errno {
    Errno::from_i32(e as i32)
}

fn proc_path(fd: &OwnedFd) -> PathBuf {
    PathBuf::from(format!("/proc/self/fd/{}", fd.as_raw_fd()))
}

fn check_name(name: &OsStr) -> Result<(), Errno> {
    if name.len() > NAME_MAX_BYTES {
        return Err(Errno::ENAMETOOLONG);
    }
    Ok(())
}

fn time(secs: i64, nsecs: i64) -> SystemTime {
    UNIX_EPOCH + Duration::new(secs.max(0) as u64, nsecs as u32)
}

fn file_attr(ino: u64, st: &FileStat) -> Option<FileAttr> {
    let kind = match st.st_mode & libc::S_IFMT {
        libc::S_IFREG => FileType::RegularFile,
        libc::S_IFDIR => FileType::Directory,
        _ => return None,
    };
    Some(FileAttr {
        ino: INodeNo(ino),
        size: st.st_size as u64,
        blocks: st.st_blocks as u64,
        atime: time(st.st_atime, st.st_atime_nsec),
        mtime: time(st.st_mtime, st.st_mtime_nsec),
        ctime: time(st.st_ctime, st.st_ctime_nsec),
        crtime: UNIX_EPOCH,
        kind,
        perm: (st.st_mode & 0o7777) as u16,
        nlink: st.st_nlink as u32,
        uid: st.st_uid,
        gid: st.st_gid,
        rdev: 0,
        blksize: 4096,
        flags: 0,
    })
}

impl State {
    fn fd(&self, ino: INodeNo) -> Result<&OwnedFd, Errno> {
        self.inodes.get(&ino.0).map(|i| &i.fd).ok_or(Errno::ENOENT)
    }

    fn lookup(&mut self, parent: INodeNo, name: &OsStr) -> Result<FileAttr, Errno> {
        let fd = openat(
            self.fd(parent)?,
            name,
            OFlag::O_PATH | OFlag::O_NOFOLLOW | OFlag::O_CLOEXEC,
            Mode::empty(),
        )
        .map_err(errno)?;
        let st = fstat(&fd).map_err(errno)?;
        let attr = file_attr(0, &st).ok_or(Errno::ENOENT)?;
        let key = (st.st_dev as u64, st.st_ino as u64);

        let ino = match self.by_key.get(&key) {
            Some(&ino) => ino,
            None => {
                let ino = self.next_ino;
                self.next_ino += 1;
                self.inodes.insert(
                    ino,
                    Inode {
                        fd,
                        key,
                        nlookup: 0,
                    },
                );
                self.by_key.insert(key, ino);
                ino
            }
        };
        self.inodes.get_mut(&ino).unwrap().nlookup += 1;

        Ok(FileAttr {
            ino: INodeNo(ino),
            ..attr
        })
    }

    fn forget(&mut self, ino: INodeNo, nlookup: u64) {
        if ino == INodeNo::ROOT {
            return;
        }
        if let Some(inode) = self.inodes.get_mut(&ino.0) {
            inode.nlookup = inode.nlookup.saturating_sub(nlookup);
            if inode.nlookup == 0 {
                let key = inode.key;
                self.inodes.remove(&ino.0);
                self.by_key.remove(&key);
            }
        }
    }

    fn getattr(&self, ino: INodeNo) -> Result<FileAttr, Errno> {
        let st = fstat(self.fd(ino)?).map_err(errno)?;
        let mut attr = file_attr(ino.0, &st).ok_or(Errno::ENOENT)?;
        let buffered = self.handles.values().find_map(|(i, h)| match h {
            Handle::Write { data, .. } if *i == ino.0 => Some(data.len()),
            _ => None,
        });
        if let Some(len) = buffered {
            attr.size = len as u64;
        }
        Ok(attr)
    }

    fn ensure_room(&self, dir: INodeNo) -> Result<(), Errno> {
        if fs::read_dir(proc_path(self.fd(dir)?))?.count() >= DIR_MAX_ENTRIES {
            return Err(Errno::ENOSPC);
        }
        Ok(())
    }

    fn add_handle(&mut self, ino: INodeNo, handle: Handle) -> u64 {
        let fh = self.next_fh;
        self.next_fh += 1;
        self.handles.insert(fh, (ino.0, handle));
        fh
    }

    fn mkdir(&mut self, parent: INodeNo, name: &OsStr) -> Result<FileAttr, Errno> {
        check_name(name)?;
        self.ensure_room(parent)?;
        mkdirat(self.fd(parent)?, name, Mode::from_bits_truncate(0o755)).map_err(errno)?;
        self.lookup(parent, name)
    }

    fn create(&mut self, parent: INodeNo, name: &OsStr) -> Result<(FileAttr, u64), Errno> {
        check_name(name)?;
        self.ensure_room(parent)?;
        let fd = openat(
            self.fd(parent)?,
            name,
            OFlag::O_CREAT | OFlag::O_EXCL | OFlag::O_RDWR | OFlag::O_CLOEXEC,
            Mode::from_bits_truncate(0o644),
        )
        .map_err(errno)?;
        let attr = self.lookup(parent, name)?;
        let fh = self.add_handle(
            attr.ino,
            Handle::Write {
                file: File::from(fd),
                data: vec![],
                dirty: false,
                failed: false,
            },
        );
        Ok((attr, fh))
    }

    fn open(&mut self, ino: INodeNo, flags: OpenFlags) -> Result<u64, Errno> {
        let path = proc_path(self.fd(ino)?);
        let handle = match flags.acc_mode() {
            OpenAccMode::O_RDONLY => Handle::Read(File::open(&path)?),
            _ => {
                let mut file = OpenOptions::new().read(true).write(true).open(&path)?;
                let truncate = flags.0 & libc::O_TRUNC != 0;
                let mut data = vec![];
                if !truncate {
                    file.read_to_end(&mut data)?;
                }
                Handle::Write {
                    file,
                    data,
                    dirty: truncate,
                    failed: false,
                }
            }
        };
        Ok(self.add_handle(ino, handle))
    }

    fn read(&self, fh: FileHandle, offset: u64, size: u32) -> Result<Vec<u8>, Errno> {
        match self.handles.get(&fh.0) {
            Some((_, Handle::Read(file))) => {
                let mut buf = vec![0; size as usize];
                let n = file.read_at(&mut buf, offset)?;
                buf.truncate(n);
                Ok(buf)
            }
            Some((_, Handle::Write { data, .. })) => {
                let start = (offset as usize).min(data.len());
                let end = start.saturating_add(size as usize).min(data.len());
                Ok(data[start..end].to_vec())
            }
            None => Err(Errno::EBADF),
        }
    }

    fn write(&mut self, fh: FileHandle, offset: u64, bytes: &[u8]) -> Result<u32, Errno> {
        let Some((
            _,
            Handle::Write {
                data,
                dirty,
                failed,
                ..
            },
        )) = self.handles.get_mut(&fh.0)
        else {
            return Err(Errno::EBADF);
        };
        let start = offset as usize;
        let end = start.saturating_add(bytes.len());
        if end > NOTE_MAX_BYTES {
            *failed = true;
            return Err(Errno::EFBIG);
        }
        if data.len() < end {
            data.resize(end, 0);
        }
        data[start..end].copy_from_slice(bytes);
        *dirty = true;
        Ok(bytes.len() as u32)
    }

    fn truncate(&mut self, ino: INodeNo, size: u64, fh: Option<FileHandle>) -> Result<(), Errno> {
        if size > NOTE_MAX_BYTES as u64 {
            return Err(Errno::EFBIG);
        }
        if let Some((_, Handle::Write { data, dirty, .. })) =
            fh.and_then(|fh| self.handles.get_mut(&fh.0))
        {
            data.resize(size as usize, 0);
            *dirty = true;
            return Ok(());
        }
        OpenOptions::new()
            .write(true)
            .open(proc_path(self.fd(ino)?))?
            .set_len(size)?;
        Ok(())
    }

    fn commit(&mut self, fh: FileHandle) -> Result<(), Errno> {
        if let Some((
            _,
            Handle::Write {
                file,
                data,
                dirty,
                failed,
            },
        )) = self.handles.get_mut(&fh.0)
            && *dirty
            && !*failed
        {
            file.write_all_at(data, 0)?;
            file.set_len(data.len() as u64)?;
            *dirty = false;
        }
        Ok(())
    }

    fn unlink(&self, parent: INodeNo, name: &OsStr, flag: UnlinkatFlags) -> Result<(), Errno> {
        unlinkat(self.fd(parent)?, name, flag).map_err(errno)
    }

    fn rename(
        &self,
        parent: INodeNo,
        name: &OsStr,
        newparent: INodeNo,
        newname: &OsStr,
        flags: RenameFlags,
    ) -> Result<(), Errno> {
        let flags = if flags.is_empty() {
            fcntl::RenameFlags::empty()
        } else if flags == RenameFlags::RENAME_NOREPLACE {
            fcntl::RenameFlags::RENAME_NOREPLACE
        } else {
            return Err(Errno::EINVAL);
        };
        check_name(newname)?;
        let replaces = fstatat(self.fd(newparent)?, newname, AtFlags::AT_SYMLINK_NOFOLLOW).is_ok();
        if parent != newparent && !replaces {
            self.ensure_room(newparent)?;
        }
        renameat2(self.fd(parent)?, name, self.fd(newparent)?, newname, flags).map_err(errno)
    }

    fn readdir(&self, ino: INodeNo) -> Result<Vec<(u64, FileType, OsString)>, Errno> {
        let mut entries = vec![
            (ino.0, FileType::Directory, OsString::from(".")),
            (ino.0, FileType::Directory, OsString::from("..")),
        ];
        for entry in fs::read_dir(proc_path(self.fd(ino)?))? {
            let entry = entry?;
            let file_type = entry.file_type()?;
            let kind = if file_type.is_file() {
                FileType::RegularFile
            } else if file_type.is_dir() {
                FileType::Directory
            } else {
                continue;
            };
            entries.push((entry.ino(), kind, entry.file_name()));
        }
        Ok(entries)
    }
}

struct Notes(Mutex<State>);

impl Notes {
    fn state(&self) -> MutexGuard<'_, State> {
        self.0.lock().unwrap()
    }
}

fn reply_empty(reply: ReplyEmpty, result: Result<(), Errno>) {
    match result {
        Ok(()) => reply.ok(),
        Err(e) => reply.error(e),
    }
}

fn reply_entry(reply: ReplyEntry, result: Result<FileAttr, Errno>) {
    match result {
        Ok(attr) => reply.entry(&TTL, &attr, GENERATION),
        Err(e) => reply.error(e),
    }
}

fn reply_attr(reply: ReplyAttr, result: Result<FileAttr, Errno>) {
    match result {
        Ok(attr) => reply.attr(&TTL, &attr),
        Err(e) => reply.error(e),
    }
}

impl Filesystem for Notes {
    fn init(&mut self, _req: &Request, config: &mut KernelConfig) -> io::Result<()> {
        config
            .add_capabilities(InitFlags::FUSE_ATOMIC_O_TRUNC)
            .map_err(|_| io::Error::other("Kernel does not support FUSE_ATOMIC_O_TRUNC"))
    }

    fn lookup(&self, _req: &Request, parent: INodeNo, name: &OsStr, reply: ReplyEntry) {
        reply_entry(reply, self.state().lookup(parent, name));
    }

    fn forget(&self, _req: &Request, ino: INodeNo, nlookup: u64) {
        self.state().forget(ino, nlookup);
    }

    fn getattr(&self, _req: &Request, ino: INodeNo, _fh: Option<FileHandle>, reply: ReplyAttr) {
        reply_attr(reply, self.state().getattr(ino));
    }

    fn setattr(
        &self,
        _req: &Request,
        ino: INodeNo,
        _mode: Option<u32>,
        _uid: Option<u32>,
        _gid: Option<u32>,
        size: Option<u64>,
        _atime: Option<TimeOrNow>,
        _mtime: Option<TimeOrNow>,
        _ctime: Option<SystemTime>,
        fh: Option<FileHandle>,
        _crtime: Option<SystemTime>,
        _chgtime: Option<SystemTime>,
        _bkuptime: Option<SystemTime>,
        _flags: Option<fuser::BsdFileFlags>,
        _kill_suid_gid: bool,
        reply: ReplyAttr,
    ) {
        let mut state = self.state();
        let result = match size {
            Some(size) => state.truncate(ino, size, fh),
            None => Ok(()),
        };
        reply_attr(reply, result.and_then(|()| state.getattr(ino)));
    }

    fn mkdir(
        &self,
        _req: &Request,
        parent: INodeNo,
        name: &OsStr,
        _mode: u32,
        _umask: u32,
        _owner: Owner,
        reply: ReplyEntry,
    ) {
        reply_entry(reply, self.state().mkdir(parent, name));
    }

    fn unlink(&self, _req: &Request, parent: INodeNo, name: &OsStr, reply: ReplyEmpty) {
        reply_empty(
            reply,
            self.state()
                .unlink(parent, name, UnlinkatFlags::NoRemoveDir),
        );
    }

    fn rmdir(&self, _req: &Request, parent: INodeNo, name: &OsStr, reply: ReplyEmpty) {
        reply_empty(
            reply,
            self.state().unlink(parent, name, UnlinkatFlags::RemoveDir),
        );
    }

    fn rename(
        &self,
        _req: &Request,
        parent: INodeNo,
        name: &OsStr,
        newparent: INodeNo,
        newname: &OsStr,
        flags: RenameFlags,
        _owner: Option<Owner>,
        reply: ReplyEmpty,
    ) {
        reply_empty(
            reply,
            self.state().rename(parent, name, newparent, newname, flags),
        );
    }

    fn open(
        &self,
        _req: &Request,
        ino: INodeNo,
        flags: OpenFlags,
        _kill_suid_gid: bool,
        reply: ReplyOpen,
    ) {
        match self.state().open(ino, flags) {
            Ok(fh) => reply.opened(FileHandle(fh), FopenFlags::empty()),
            Err(e) => reply.error(e),
        }
    }

    fn read(
        &self,
        _req: &Request,
        _ino: INodeNo,
        fh: FileHandle,
        offset: u64,
        size: u32,
        _flags: OpenFlags,
        _lock_owner: Option<LockOwner>,
        reply: ReplyData,
    ) {
        match self.state().read(fh, offset, size) {
            Ok(data) => reply.data(&data),
            Err(e) => reply.error(e),
        }
    }

    fn write(
        &self,
        _req: &Request,
        _ino: INodeNo,
        fh: FileHandle,
        offset: u64,
        data: &[u8],
        _write_flags: WriteFlags,
        _flags: OpenFlags,
        _lock_owner: Option<LockOwner>,
        reply: ReplyWrite,
    ) {
        match self.state().write(fh, offset, data) {
            Ok(n) => reply.written(n),
            Err(e) => reply.error(e),
        }
    }

    fn flush(
        &self,
        _req: &Request,
        _ino: INodeNo,
        fh: FileHandle,
        _lock_owner: LockOwner,
        reply: ReplyEmpty,
    ) {
        reply_empty(reply, self.state().commit(fh));
    }

    fn release(
        &self,
        _req: &Request,
        _ino: INodeNo,
        fh: FileHandle,
        _flags: OpenFlags,
        _lock_owner: Option<LockOwner>,
        _flush: bool,
        reply: ReplyEmpty,
    ) {
        let mut state = self.state();
        let result = state.commit(fh);
        state.handles.remove(&fh.0);
        reply_empty(reply, result);
    }

    fn fsync(
        &self,
        _req: &Request,
        _ino: INodeNo,
        fh: FileHandle,
        _datasync: bool,
        reply: ReplyEmpty,
    ) {
        reply_empty(reply, self.state().commit(fh));
    }

    fn readdir(
        &self,
        _req: &Request,
        ino: INodeNo,
        _fh: FileHandle,
        offset: u64,
        mut reply: ReplyDirectory,
    ) {
        match self.state().readdir(ino) {
            Ok(entries) => {
                for (i, (ino, kind, name)) in entries.into_iter().enumerate().skip(offset as usize)
                {
                    if reply.add(INodeNo(ino), i as u64 + 1, kind, name) {
                        break;
                    }
                }
                reply.ok();
            }
            Err(e) => reply.error(e),
        }
    }

    fn create(
        &self,
        _req: &Request,
        parent: INodeNo,
        name: &OsStr,
        _mode: u32,
        _umask: u32,
        _flags: i32,
        _kill_suid_gid: bool,
        _owner: Owner,
        reply: ReplyCreate,
    ) {
        match self.state().create(parent, name) {
            Ok((attr, fh)) => {
                reply.created(&TTL, &attr, GENERATION, FileHandle(fh), FopenFlags::empty())
            }
            Err(e) => reply.error(e),
        }
    }
}
