# ClipPanel optional folder sync

ClipPanel is local-first. Sync is never enabled automatically and no ClipPanel service receives
clipboard data. The only sync action is **Sync encrypted archive…** in the Library: the user picks
one folder and enters an archive password for that one action.

The app first merges `ClipPanel.sync.cliparchive` from that folder, then writes a fresh AES-GCM
encrypted archive back to the same location. The password is not retained. A user may choose a
folder backed by iCloud Drive, Dropbox, a network share, or removable storage, but those services
only see encrypted ciphertext, archive size, and modification time.

This is designed for end-to-end privacy between machines that share the same password. It does not
hide metadata from the folder provider, resolve simultaneous-write conflicts, recover a forgotten
password, or protect a machine that is already compromised. Users should choose a strong, unique
password and avoid enabling sync for clips they would not want represented in an encrypted archive.
