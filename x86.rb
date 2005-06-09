#!/usr/bin/ruby

module Rex
module Arch

#
# everything here is mostly stole from vlad's perl x86 stuff
#

module X86

	#
	# Register number constants
	#
	EAX = AL = AX = ES = 0
	ECX = CL = CX = CS = 1
	EDX = DL = DX = SS = 2
	EBX = BL = BX = DS = 3
	ESP = AH = SP = FS = 4
	EBP = CH = BP = GS = 5
	ESI = DH = SI =      6
	EDI = BH = DI =      7

	def self.reg_number(str)
		return self.const_get(str.upcase)
	end


	def self.encode_modrm(dst, src)
		_check_reg(dst, src)
		return (0xc0 | src | dst << 3).chr
	end

	def self.push_byte(byte)
		# push byte will sign extend...
		if byte < 128 && byte >= -128
			return "\x6a" + (byte & 0xff).chr
		end
		raise ::RangeError, "Can only take signed byte values!", caller()
	end
	def self.pop_dword(dst)
		_check_reg(dst)
		return (0x58 | dst).chr
	end

	def self.clear(reg, badchars = '')
		_check_reg(reg)
		opcodes = Rex::StringUtils.remove_badchars("\x29\x2b\x31\x33", badchars)
		if opcodes.empty?
			raise RuntimeError, "Could not find a usable opcode", caller()
		end

		return opcodes[rand(opcodes.length)].chr + encode_modrm(reg, reg)
	end

	# B004 mov al,0x4
	def self.mov_byte(reg, val)
		_check_reg(reg)
		# chr will raise RangeError if val not between 0 .. 255
		return (0xb0 | reg).chr + val.chr
	end

	# 66B80400 mov ax,0x4
	def self.mov_word(reg, val)
		_check_reg(reg)
		if val < 0 || val > 0xffff
			raise RangeError, "Can only take unsigned word values!", caller()
		end
		return "\x66" + (0xb8 | reg).chr + [ val ].pack('v')
	end

	def self.set(dst, val, badchars = '')
		_check_reg(dst)

		# try push BYTE val; pop dst
		begin
			return _check_badchars(push_byte(val) + pop_dword(dst), badchars)
		rescue RuntimeError, RangeError
		end

		# try clear dst, mov BYTE dst
		begin
			return _check_badchars(clear(dst, badchars) + mov_byte(dst, val), badchars)
		rescue RuntimeError, RangeError
		end

		# try clear dst, mov WORD dst
		begin
			return _check_badchars(clear(dst, badchars) + mov_word(dst, val), badchars)
		rescue RuntimeError, RangeError
		end

		raise RuntimeError, "No valid set instruction could be created!", caller()
	end

	def self._check_reg(*regs)
		regs.each { |reg|
			if reg > 7 || reg < 0
				raise ArgumentError, "Invalid register #{reg}", caller()
			end
		}
		return nil
	end

	def self._check_badchars(data, badchars)
		idx = Rex::StringUtils.badchar_index(data, badchars)
		if idx
			raise RuntimeError, "Bad character at #{idx}", caller()
		end
		return data
	end

end

end end
