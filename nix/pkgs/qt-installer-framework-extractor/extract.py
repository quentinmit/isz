import argparse
import os
import os.path

import kaitaistruct
from kaitaistruct import KaitaiStruct, KaitaiStream, BytesIO
from enum import Enum

# Generated with `ksc qt_installer_framework.ksy -t python`
# from https://github.com/prebuilder/QtInstallerFrameworkExtractor.cpp

if getattr(kaitaistruct, 'API_VERSION', (0, 9)) < (0, 9):
    raise Exception("Incompatible Kaitai Struct Python API: 0.9 or later is required, but you have %s" % (kaitaistruct.__version__))

class QtInstallerFramework(KaitaiStruct):
    """Qt installer framework is a set of libs to make SFX installers. Installers usually contain 7zip-compressed archives. Obviously, Qt installer itself is built using this framework.

    Warning 1: KSC has a bug. It makes the computed values be int32_t. Of course their type should be either explicitly specified by a programmer or derived automatically. The workaroind is to just replace all int32_t to int64_t in sources.
    Warning 2: don't use this spec on Linux against Qt distribution with overcommit enabled unless you have lot of RAM (> 12 GiB). There is a severe memory leak somewhere (currently I have no idea where exactly). The leak is present in both C++ and python-compiled code. In python even if I have patched the generated source to explicitly free all the `bytes`, `BytesIO`s and `KaitaiStream` objects the leak is still present. At least it is neither in `bytes` nor in `BytesIO`. In C++ I have not patched anything but used move semantics to free the stuff since std::unique_ptr is used. The leak is still present. IDK where it is and how to fix it.

    .. seealso::
       Source - https://wiki.qt.io/Qt-Installer-Framework


    .. seealso::
       Source - https://github.com/qtproject/installer-framework/blob/master/src/libs/installer/binaryformat.cpp


    .. seealso::
       Source - https://github.com/qtproject/installer-framework/blob/master/src/libs/installer/binarycontent.cpp


    .. seealso::
       Source - https://github.com/qtproject/installer-framework/blob/master/src/libs/installer/binarycontent.h
    """
    def __init__(self, magic_cookie_offset, _io, _parent=None, _root=None):
        self._io = _io
        self._parent = _parent
        self._root = _root if _root else self
        self.magic_cookie_offset = magic_cookie_offset
        self._read()

    def _read(self):
        pass

    class Array(KaitaiStruct):
        def __init__(self, _io, _parent=None, _root=None):
            self._io = _io
            self._parent = _parent
            self._root = _root if _root else self
            self._read()

        def _read(self):
            self.size = self._io.read_u8le()
            self.value = self._io.read_bytes(self.size)


    class String(KaitaiStruct):
        def __init__(self, _io, _parent=None, _root=None):
            self._io = _io
            self._parent = _parent
            self._root = _root if _root else self
            self._read()

        def _read(self):
            self.size = self._io.read_u8le()
            self.value = (self._io.read_bytes(self.size)).decode(u"utf-8")


    class Header(KaitaiStruct):
        def __init__(self, _io, _parent=None, _root=None):
            self._io = _io
            self._parent = _parent
            self._root = _root if _root else self
            self._read()

        def _read(self):
            self.meta_resources_count = self._io.read_u8le()
            self.unkn = []
            for i in range(2):
                self.unkn.append(self._io.read_u8le())

            self.cookie = QtInstallerFramework.Header.CookieIdentifier(self._io, self, self._root)

        class MarkerIdentifier(KaitaiStruct):

            class Type(Enum):
                installer = 51
                uninstaller = 52
                updater = 53
                package_manager = 54
            def __init__(self, _io, _parent=None, _root=None):
                self._io = _io
                self._parent = _parent
                self._root = _root if _root else self
                self._read()

            def _read(self):
                self.type = KaitaiStream.resolve_enum(QtInstallerFramework.Header.MarkerIdentifier.Type, self._io.read_u1())
                self.signature = self._io.read_bytes(3)
                if not self.signature == b"\x32\x02\x12":
                    raise kaitaistruct.ValidationNotEqualError(b"\x32\x02\x12", self.signature, self._io, u"/types/header/types/marker_identifier/seq/1")


        class CookieIdentifier(KaitaiStruct):

            class Type(Enum):
                binary = 248
                data = 249
            def __init__(self, _io, _parent=None, _root=None):
                self._io = _io
                self._parent = _parent
                self._root = _root if _root else self
                self._read()

            def _read(self):
                self.type = KaitaiStream.resolve_enum(QtInstallerFramework.Header.CookieIdentifier.Type, self._io.read_u1())
                self.signature = self._io.read_bytes(7)
                if not self.signature == b"\x68\xD6\x99\x1C\x0A\x63\xC2":
                    raise kaitaistruct.ValidationNotEqualError(b"\x68\xD6\x99\x1C\x0A\x63\xC2", self.signature, self._io, u"/types/header/types/cookie_identifier/seq/1")


        class Range(KaitaiStruct):
            def __init__(self, _io, _parent=None, _root=None):
                self._io = _io
                self._parent = _parent
                self._root = _root if _root else self
                self._read()

            def _read(self):
                self.start_read = self._io.read_s8le()
                self.size = self._io.read_s8le()

            @property
            def start(self):
                if hasattr(self, '_m_start'):
                    return self._m_start

                self._m_start = (self._root.header.binary_descriptor.end_of_exectuable + self.start_read)
                return getattr(self, '_m_start', None)


        class BinaryDescriptor(KaitaiStruct):
            def __init__(self, _io, _parent=None, _root=None):
                self._io = _io
                self._parent = _parent
                self._root = _root if _root else self
                self._read()

            def _read(self):
                self.resources_count = self._io.read_s8le()
                self.binary_content_size = self._io.read_s8le()
                self.marker = QtInstallerFramework.Header.MarkerIdentifier(self._io, self, self._root)

            class SegmentsDescriptor(KaitaiStruct):
                def __init__(self, _io, _parent=None, _root=None):
                    self._io = _io
                    self._parent = _parent
                    self._root = _root if _root else self
                    self._read()

                def _read(self):
                    self.resource_collections_segment = QtInstallerFramework.Header.Range(self._io, self, self._root)
                    self.meta_resource_segments = []
                    for i in range(self._parent._parent.meta_resources_count):
                        self.meta_resource_segments.append(QtInstallerFramework.Header.Range(self._io, self, self._root))

                    self.operations_segment = QtInstallerFramework.Header.Range(self._io, self, self._root)

                class Operations(KaitaiStruct):
                    def __init__(self, _io, _parent=None, _root=None):
                        self._io = _io
                        self._parent = _parent
                        self._root = _root if _root else self
                        self._read()

                    def _read(self):
                        self.count = self._io.read_u8le()
                        self.operations = []
                        for i in range(self.count):
                            self.operations.append(QtInstallerFramework.Header.BinaryDescriptor.SegmentsDescriptor.Operations.Operation(self._io, self, self._root))

                        self.reserved = self._io.read_u8le()

                    class Operation(KaitaiStruct):
                        def __init__(self, _io, _parent=None, _root=None):
                            self._io = _io
                            self._parent = _parent
                            self._root = _root if _root else self
                            self._read()

                        def _read(self):
                            self.name = QtInstallerFramework.String(self._io, self, self._root)
                            self.xml = QtInstallerFramework.String(self._io, self, self._root)



                class Collections(KaitaiStruct):
                    def __init__(self, _io, _parent=None, _root=None):
                        self._io = _io
                        self._parent = _parent
                        self._root = _root if _root else self
                        self._read()

                    def _read(self):
                        self.count = self._io.read_s8le()
                        self.collections = []
                        for i in range(self.count):
                            self.collections.append(QtInstallerFramework.Header.BinaryDescriptor.SegmentsDescriptor.Collections.Collection(self._io, self, self._root))


                    class Collection(KaitaiStruct):
                        def __init__(self, _io, _parent=None, _root=None):
                            self._io = _io
                            self._parent = _parent
                            self._root = _root if _root else self
                            self._read()

                        def _read(self):
                            self.name = QtInstallerFramework.String(self._io, self, self._root)
                            self.segment_range = QtInstallerFramework.Header.Range(self._io, self, self._root)

                        class Segment(KaitaiStruct):
                            def __init__(self, _io, _parent=None, _root=None):
                                self._io = _io
                                self._parent = _parent
                                self._root = _root if _root else self
                                self._read()

                            def _read(self):
                                self.count = self._io.read_u8le()
                                self.resources = []
                                for i in range(self.count):
                                    self.resources.append(QtInstallerFramework.Header.BinaryDescriptor.SegmentsDescriptor.Collections.Collection.Segment.Resource(self._io, self, self._root))


                            class Resource(KaitaiStruct):
                                def __init__(self, _io, _parent=None, _root=None):
                                    self._io = _io
                                    self._parent = _parent
                                    self._root = _root if _root else self
                                    self._read()

                                def _read(self):
                                    self.name = QtInstallerFramework.String(self._io, self, self._root)
                                    self.segment = QtInstallerFramework.Header.Range(self._io, self, self._root)



                        @property
                        def segment(self):
                            if hasattr(self, '_m_segment'):
                                return self._m_segment

                            io = self._root._io
                            _pos = io.pos()
                            io.seek(self.segment_range.start)
                            self._raw__m_segment = io.read_bytes(self.segment_range.size)
                            _io__raw__m_segment = KaitaiStream(BytesIO(self._raw__m_segment))
                            self._m_segment = QtInstallerFramework.Header.BinaryDescriptor.SegmentsDescriptor.Collections.Collection.Segment(_io__raw__m_segment, self, self._root)
                            io.seek(_pos)
                            return getattr(self, '_m_segment', None)



                @property
                def collections(self):
                    if hasattr(self, '_m_collections'):
                        return self._m_collections

                    io = self._root._io
                    _pos = io.pos()
                    io.seek(self.resource_collections_segment.start)
                    self._raw__m_collections = io.read_bytes(self.resource_collections_segment.size)
                    _io__raw__m_collections = KaitaiStream(BytesIO(self._raw__m_collections))
                    self._m_collections = QtInstallerFramework.Header.BinaryDescriptor.SegmentsDescriptor.Collections(_io__raw__m_collections, self, self._root)
                    io.seek(_pos)
                    return getattr(self, '_m_collections', None)

                @property
                def operations(self):
                    if hasattr(self, '_m_operations'):
                        return self._m_operations

                    io = self._root._io
                    _pos = io.pos()
                    io.seek(self.operations_segment.start)
                    self._raw__m_operations = io.read_bytes(self.operations_segment.size)
                    _io__raw__m_operations = KaitaiStream(BytesIO(self._raw__m_operations))
                    self._m_operations = QtInstallerFramework.Header.BinaryDescriptor.SegmentsDescriptor.Operations(_io__raw__m_operations, self, self._root)
                    io.seek(_pos)
                    return getattr(self, '_m_operations', None)


            @property
            def size_of_segment_descriptor(self):
                if hasattr(self, '_m_size_of_segment_descriptor'):
                    return self._m_size_of_segment_descriptor

                self._m_size_of_segment_descriptor = ((self._parent.meta_resources_count + 2) * 16)
                return getattr(self, '_m_size_of_segment_descriptor', None)

            @property
            def segments_descriptor(self):
                if hasattr(self, '_m_segments_descriptor'):
                    return self._m_segments_descriptor

                io = self._root._io
                _pos = io.pos()
                io.seek((self._parent.binary_descriptor_offset - self.size_of_segment_descriptor))
                self._raw__m_segments_descriptor = io.read_bytes(self.size_of_segment_descriptor)
                _io__raw__m_segments_descriptor = KaitaiStream(BytesIO(self._raw__m_segments_descriptor))
                self._m_segments_descriptor = QtInstallerFramework.Header.BinaryDescriptor.SegmentsDescriptor(_io__raw__m_segments_descriptor, self, self._root)
                io.seek(_pos)
                return getattr(self, '_m_segments_descriptor', None)

            @property
            def end_of_exectuable(self):
                if hasattr(self, '_m_end_of_exectuable'):
                    return self._m_end_of_exectuable

                self._m_end_of_exectuable = (self._parent._root.end_of_binary_content - self.binary_content_size)
                return getattr(self, '_m_end_of_exectuable', None)


        @property
        def other_stuff_size(self):
            """meta count, offset/length collection index, marker, cookie..."""
            if hasattr(self, '_m_other_stuff_size'):
                return self._m_other_stuff_size

            self._m_other_stuff_size = (4 * 8)
            return getattr(self, '_m_other_stuff_size', None)

        @property
        def binary_descriptor_offset(self):
            if hasattr(self, '_m_binary_descriptor_offset'):
                return self._m_binary_descriptor_offset

            self._m_binary_descriptor_offset = (self._root.end_of_binary_content - self.other_stuff_size)
            return getattr(self, '_m_binary_descriptor_offset', None)

        @property
        def binary_descriptor(self):
            if hasattr(self, '_m_binary_descriptor'):
                return self._m_binary_descriptor

            io = self._root._io
            _pos = io.pos()
            io.seek(self.binary_descriptor_offset)
            self._raw__m_binary_descriptor = io.read_bytes(20)
            _io__raw__m_binary_descriptor = KaitaiStream(BytesIO(self._raw__m_binary_descriptor))
            self._m_binary_descriptor = QtInstallerFramework.Header.BinaryDescriptor(_io__raw__m_binary_descriptor, self, self._root)
            io.seek(_pos)
            return getattr(self, '_m_binary_descriptor', None)


    @property
    def end_of_binary_content(self):
        if hasattr(self, '_m_end_of_binary_content'):
            return self._m_end_of_binary_content

        self._m_end_of_binary_content = (self.magic_cookie_offset + 8)
        return getattr(self, '_m_end_of_binary_content', None)

    @property
    def header(self):
        if hasattr(self, '_m_header'):
            return self._m_header

        _pos = self._io.pos()
        self._io.seek((self.end_of_binary_content - 32))
        self._m_header = QtInstallerFramework.Header(self._io, self, self._root)
        self._io.seek(_pos)
        return getattr(self, '_m_header', None)

MAGIC = bytes([0xf8, 0x68, 0xd6, 0x99, 0x1c, 0x0a, 0x63, 0xc2])

def main():
    parser = argparse.ArgumentParser(description='Extract Qt Installer Framework installers')
    parser.add_argument("file", metavar="FILE")
    parser.add_argument("-x", "--extract", "-x", action="store_true")
    parser.add_argument("-d", "--destination", default=".")

    args = parser.parse_args()

    with open(args.file, "rb") as f:
        offset = f.seek(-1024 * 1024, os.SEEK_END)

        lastmeg = f.read()
        magic_pos = offset + lastmeg.find(MAGIC)

        data = QtInstallerFramework(magic_pos, KaitaiStream(f))

        segments_descriptor = data.header.binary_descriptor.segments_descriptor

        for i, collection in enumerate(segments_descriptor.collections.collections):
            print("%3d: %s" % (i, collection.name.value))
            for j, resource in enumerate(collection.segment.resources):
                print("      %3d: %s [%d+%d]" % (j, resource.name.value, resource.segment.start, resource.segment.size))
                if args.extract:
                    f.seek(resource.segment.start)
                    open(os.path.join(args.destination, resource.name.value), "wb").write(f.read(resource.segment.size))

if __name__ == "__main__":
    main()
