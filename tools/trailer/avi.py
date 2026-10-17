"""Reads what Godot's Movie Maker writes to an .avi: a JPEG per picture
(chunks 00db) and the sound of that picture as 16-bit PCM (chunks 01wb), in
the order they were made. No decoder is needed: the pictures are JPEG files
as they are, and the sound is raw samples."""
import struct


class Take:
    """One .avi: `pictures` are (offset, size) of every JPEG in the file,
    `sound` the samples of all of it as bytes, `rate` and `channels` theirs."""

    def __init__(self, path):
        self.path = path
        with open(path, "rb") as file:
            self.data = file.read()
        self.pictures = []
        sound = []
        self.rate = 48000
        self.channels = 2
        self._walk(0, len(self.data), sound)
        self.sound = b"".join(sound)

    def _walk(self, at, end, sound):
        data = self.data
        while at + 8 <= end:
            kind = data[at:at + 4]
            size = struct.unpack("<I", data[at + 4:at + 8])[0]
            if kind in (b"RIFF", b"LIST"):
                self._walk(at + 12, min(at + 8 + size, end), sound)
            elif kind in (b"00db", b"00dc"):
                self.pictures.append((at + 8, size))
            elif kind == b"01wb":
                sound.append(data[at + 8:at + 8 + size])
            elif kind == b"strf" and size >= 16 and struct.unpack("<H", data[at + 8:at + 10])[0] == 1:
                # WAVEFORMATEX of the sound: PCM, its channels and rate.
                self.channels, self.rate = struct.unpack("<HI", data[at + 10:at + 16])
            elif kind == b"idx1":
                break
            at += 8 + size + (size & 1)

    def picture(self, index):
        """The JPEG of picture `index`, as bytes."""
        offset, size = self.pictures[index]
        return self.data[offset:offset + size]

    def samples_per_picture(self, fps):
        return self.rate // fps
