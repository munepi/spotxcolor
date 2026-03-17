#!/usr/bin/env ruby
# frozen_string_literal: true

# ase2def.rb
# A script to extract CMYK spot colors from Adobe Swatch Exchange (.ase) files
# and generate a .def file for the spotxcolor LaTeX package.

if ARGV.empty?
  puts "Usage: ruby ase2def.rb <input.ase> [output.def]"
  exit 1
end

input_file = ARGV[0]
output_file = ARGV[1] || input_file.sub(/\.ase$/i, '.def')

# UTF-16BE (Big Endian) の文字列を読み込むヘルパー関数
def read_ase_string(f)
  # 文字列の長さ（UTF-16の文字数、null終端を含む）
  len = f.read(2).unpack1('n')
  return "" if len == 0

  # バイト数は文字数の2倍
  bytes = f.read(len * 2)
  # UTF-16BEからUTF-8に変換し、末尾のnull文字を削除
  bytes.force_encoding('UTF-16BE').encode('UTF-8').chomp("\x00")
end

begin
  File.open(input_file, 'rb') do |f|
    # 1. Header Check
    signature = f.read(4)
    unless signature == 'ASEF'
      raise "Invalid signature '#{signature}'. Not a valid ASE file."
    end

    version_major, version_minor = f.read(4).unpack('n2')
    block_count = f.read(4).unpack1('N')

    puts "ASE Version : #{version_major}.#{version_minor}"
    puts "Total Blocks: #{block_count}"

    colors = []

    # 2. Parse Blocks
    block_count.times do
      block_type = f.read(2).unpack1('n') # 0xC001: Group Start, 0xC002: Group End, 0x0001: Color
      block_len = f.read(4).unpack1('N')

      case block_type
      when 0xC001 # Group Start
        # 修正箇所: read_acb_string -> read_ase_string
        group_name = read_ase_string(f)
      when 0xC002 # Group End
        # Do nothing
      when 0x0001 # Color Block
        # Read the raw block data
        block_data = f.read(block_len)

        # We process the block data manually since we know its length
        require 'stringio'
        b = StringIO.new(block_data)

        color_name = read_ase_string(b)

        # Color Model (4 chars: "CMYK", "RGB ", "LAB ", "Gray")
        color_model = b.read(4)

        # The channel values are stored as 32-bit single-precision floats (Big Endian)
        case color_model
        when "CMYK"
          c, m, y, k = b.read(16).unpack('g4') # 'g' is big-endian single-precision float
          # Format floats to 4 decimal places
          val_str = [c, m, y, k].map { |v| v.round(4) }.join(", ")
        when "RGB "
          r, g, b_val = b.read(12).unpack('g3')
          val_str = [r, g, b_val].map { |v| v.round(4) }.join(", ")
        when "LAB "
          l, a, b_val = b.read(12).unpack('g3')
          val_str = [l, a, b_val].map { |v| v.round(4) }.join(", ")
        when "Gray"
          gray = b.read(4).unpack1('g')
          val_str = gray.round(4).to_s
        else
          # Skip unknown
          next
        end

        # Color Type (0=Global, 1=Spot, 2=Normal)
        color_type = b.read(2).unpack1('n')

        # Create a safe macro name (remove spaces, hyphens, and asterisks)
        macro_name = color_name.gsub(/[\s\-\*\/]/, '')

        colors << {
          macro_name: macro_name,
          pdf_name: color_name,
          model: color_model,
          values: val_str,
          is_spot: color_type == 1
        }
      else
        # Skip unknown block types
        f.read(block_len)
      end
    end

    # 3. Write to .def
    File.open(output_file, 'w') do |out|
      base_name = File.basename(output_file, '.*')
      out.puts "% spotxcolor definition file: #{base_name}"
      out.puts "% Auto-generated from .ase"
      out.puts ""
      out.puts "\\ProvidesFile{#{File.basename(output_file)}}[Spot color definitions]"
      out.puts ""

      cmyk_count = 0
      other_count = 0

      colors.each do |c|
        if c[:model] == "CMYK"
          out.puts "\\definespotcolor{#{c[:macro_name]}}{#{c[:pdf_name]}}{#{c[:values]}}"
          cmyk_count += 1
        else
          # CMYK以外の場合はコメントアウト
          out.puts "% \\definespotcolor{#{c[:macro_name]}}{#{c[:pdf_name]}}{#{c[:values]}} % Need CMYK conversion (#{c[:model].strip})"
          other_count += 1
        end
      end
      out.puts "\\endinput"

      puts "Extraction Complete!"
      puts " - CMYK Colors extracted: #{cmyk_count}"
      if other_count > 0
        puts " - Non-CMYK Colors skipped (commented out): #{other_count}"
      end
    end

  end
rescue => e
  puts "Error processing file: #{e.class} - #{e.message}"
  puts e.backtrace.join("\n")
end
