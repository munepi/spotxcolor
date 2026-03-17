#!/usr/bin/env ruby
# frozen_string_literal: true

# acbl2def.rb
# A script to extract CMYK spot colors from Adobe Color Book Legacy (.acbl) XML files
# and generate a .def file for the spotxcolor LaTeX package.

if ARGV.empty?
  puts "Usage: ruby acbl2def.rb <input.acbl> [output.def]"
  exit 1
end

input_file = ARGV[0]
output_file = ARGV[1] || input_file.sub(/\.acbl$/i, '.def')

begin
  xml_content = File.read(input_file, encoding: 'UTF-8')

  # プレフィックスの抽出 (例: <PrefixPostfixPair Prefix="DIC " Postfix=""/>)
  prefix = ""
  if xml_content =~ /<PrefixPostfixPair Prefix="([^"]*)"/
    prefix = $1
  end

  colors = []

  # <Sp> タグをすべて抽出
  # 例: <Sp N="1s"><A N="1p"/><C>0 0.16 0.17 0</C></Sp>
  xml_content.scan(/<Sp N="([^"]+)".*?<C>([^<]+)<\/C><\/Sp>/m) do |name, cmyk_vals|

    full_pdf_name = "#{prefix}#{name}"

    # LaTeXマクロ名として安全な形に整形 (空白、ハイフン、アスタリスク等を除去)
    macro_name = full_pdf_name.gsub(/[\s\-\*\/]/, '')

    # CMYK値のスペース区切りをカンマ区切りに変換
    cmyk_csv = cmyk_vals.strip.split(/\s+/).map { |v| v.to_f.round(4).to_s }.join(", ")

    colors << {
      macro: macro_name,
      pdf_name: full_pdf_name,
      cmyk: cmyk_csv
    }
  end

  # .def ファイルへの書き出し
  File.open(output_file, 'w', encoding: 'UTF-8') do |out|
    base_name = File.basename(output_file, '.*')
    out.puts "% spotxcolor definition file: #{base_name}"
    out.puts "% Auto-generated natively from Adobe .acbl (CMYK exact values)"
    out.puts ""
    out.puts "\\ProvidesFile{#{File.basename(output_file)}}[Spot color definitions]"
    out.puts ""

    colors.each do |c|
      out.puts "\\definespotcolor{#{c[:macro]}}{#{c[:pdf_name]}}{#{c[:cmyk]}}"
    end
    out.puts "\\endinput"
  end

  puts "Successfully extracted #{colors.size} CMYK colors natively from ACBL."
  puts "Output saved to: #{output_file}" # <-- 修正箇所

rescue => e
  puts "Error: #{e.message}"
end
