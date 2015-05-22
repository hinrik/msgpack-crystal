require "./msgpack/types"

class Msgpack
    alias Integers = (Int8|Int16|Int32|Int64)
    alias UnsignedIntegers = (UInt8|UInt16|UInt32|UInt64)
    alias MsgpackTypes = (Nil|Bool|Integers|UnsignedIntegers|String|Float32|Float64|Array(MsgpackTypes)|Hash(MsgpackTypes,MsgpackTypes))

    def self.unpack(packed : String)
        unpack(packed.bytes)
    end

    def self.unpack(bytes : Array(Int))
        unpack(Slice(UInt8).new(bytes.size.to_i32) { |i| bytes[i].to_u8 })
    end

    def self.unpack(bytes : Array(UInt8))
        unpack(Slice(UInt8).new(bytes.size.to_i32) { |i| bytes[i] })
    end

    def self.unpack(bytes : Slice(UInt8))
        Unpacker.new(bytes).next_value
    end

    class Unpacker
        def initialize(buffer : Slice(UInt8))
            @buffer = buffer
            @offset = 0
        end

        def each
            yield next_value
        end

        def next_value
            type = read_byte

            case type
            when 0xA0..0xBF
                size  = type - 0xA0
                read_string(size)
            when 0x00..0x7f
                type
            when 0x80..0x8f
                size = type - 0x80
                read_hash(size)
            when 0x90..0x9f
                size = type - 0x90
                read_array(size)
            when 0xE0..0xFF
                type.to_i8
            when 0xC0
                nil
            when 0xC2
                false
            when 0xC3
                true
            when 0xC4
                size = read_byte
                read_string(size)
            when 0xC5
                size = read_uint16
                read_string(size)
            when 0xC6
                size = read_uint32
                read_string(size)
            when 0xCA
                convert(LibMsgpack::Float, read_bytes(4))
            when 0xCB
                convert(LibMsgpack::Double, read_bytes(8))
            when 0xCC
                read_byte
            when 0xCD
                read_uint16
            when 0xCE
                read_uint32
            when 0xCF
                read_uint64
            when 0xD0
                read_byte.to_i8
            when 0xD1
                read_int16
            when 0xD2
                read_int32
            when 0xD3
                read_int64
            when 0xD9
                size  = read_byte
                read_string(size)
            when 0xDA
                size  = read_uint16
                read_string(size)
            when 0xDB
                size  = read_uint32
                read_string(size)
            when 0xDC
                size  = read_uint16
                read_array(size)
            when 0xDD
                size  = read_uint32
                read_array(size)
            when 0xDE
                size  = read_uint16
                read_hash(size)
            when 0xDF
                size  = read_uint32
                read_hash(size)
            end
        end

        private def read_byte
            read_bytes(1)[0].to_u8
        end

        private def read_bytes(size)
            slice = @buffer[@offset, size.to_i32]
            @offset += size
            slice
        end

        private def convert(klass, bytes)
            type = klass.new
            size = bytes.length
            case size
                when 2
                    type.byte_array = StaticArray(UInt8, 2).new { |i| bytes[1 - i] }
                when 4
                    type.byte_array = StaticArray(UInt8, 4).new { |i| bytes[3 - i] }
                else
                    type.byte_array = StaticArray(UInt8, 8).new { |i| bytes[7 - i] }
            end
            type.value
        end

        private def read_string(size)
            string = StringIO.new
            read_bytes(size).each_slice(4048) do |slice|
              string.write Slice(UInt8).new(slice.size.to_i32) { |i| slice[i] }
            end
            string.to_s
        end

        private def read_int16
            convert(LibMsgpack::Int16, read_bytes(2))
        end

        private def read_int32
            convert(LibMsgpack::Int32, read_bytes(4))
        end

        private def read_int64
            convert(LibMsgpack::Int64, read_bytes(8))
        end

        private def read_uint16
            convert(LibMsgpack::UInt16, read_bytes(2))
        end

        private def read_uint32
            convert(LibMsgpack::UInt32, read_bytes(4))
        end

        private def read_uint64
            convert(LibMsgpack::UInt64, read_bytes(8))
        end

        private def read_array(size)
            array = Array(MsgpackTypes).new(size)
            size.times do
                array << next_value
            end
            array
        end

        private def read_hash(size)
            hash = Hash(MsgpackTypes, MsgpackTypes).new(size)
            size.times do
                hash[next_value] = next_value
            end
            hash
        end
    end
end