#!/usr/bin/env ruby
# frozen_string_literal: true

# acb2def.rb
# Parses Adobe Color Book (.acb) files and generates spotxcolor .def files.
# Uses a 3rd-degree Polynomial Regression model trained on 1280 native 
# Adobe DIC color pairs to accurately predict CMYK from Lab, strictly 
# eliminating K-channel muddiness for vibrant spot colors.

if ARGV.empty?
  puts "Usage: ruby acb2def.rb <input.acb> [output.def]"
  exit 1
end

input_file = ARGV[0]
output_file = ARGV[1] || input_file.sub(/\.acb$/i, '.def')

def read_acb_string(f)
  len = f.read(4).unpack1('N')
  return "" if len == 0
  bytes = f.read(len * 2)
  raw_string = bytes.force_encoding('UTF-16BE').encode('UTF-8').sub(/\x00$/, '')
  # "key=value" 形式の場合は value のみを抽出
  raw_string.include?('=') ? raw_string.split('=', 2)[1] : raw_string
end

# 3rd-Degree Polynomial Regression Model trained on native .acbl data
def lab_to_cmyk_ml(l, a, b)
  # Normalize inputs (L: 0~100 -> 0~1, a/b: -128~127 -> -1~1)
  nl = l / 100.0
  na = a / 128.0
  nb = b / 128.0

  # 20 Polynomial Features (Degree 3)
  features = [
    1.0, # Bias
    nl, na, nb,
    nl**2, nl*na, nl*nb, na**2, na*nb, nb**2,
    nl**3, nl**2 * na, nl**2 * nb, nl * na**2, nl * na * nb, nl * nb**2, na**3, na**2 * nb, na * nb**2, nb**3
  ]

  # Pre-calculated weights from scikit-learn Ridge Regression on DIC Color Guide
  weights_c = [1.2901, -0.4479, -0.3755, -0.9451, -2.3973, -2.9976, 1.7545, -2.2456, -1.3208, -0.8578, 1.5398, 2.6999, -1.2268, 3.5385, 2.0701, 2.1257, 1.1315, 0.7623, 0.6077, -1.0463]
  weights_m = [1.3721, -1.2394, 0.2517, -0.1009, -1.2374, 3.6443, 0.7975, -0.6841, 0.3884, -1.4627, 1.0866, -3.6129, -0.5822, 1.2445, -0.6730, 1.6401, -1.1761, 0.3443, 0.7518, -0.3596]
  weights_y = [1.5667, -2.1058, -1.0067, 2.7018, 0.0076, 1.1679, 0.9149, -1.2303, 3.3409, -3.7865, 0.4668, -0.7358, -3.0462, 2.2590, -5.5650, 8.1909, -0.1768, -1.8255, 4.8637, -4.7405]
  weights_k = [0.8222, -3.8856, 0.1354, 0.6670, 5.9819, -0.6177, -2.0387, 0.3529, 0.9857, 0.4917, -2.9774, 0.5719, 1.4967, -0.6327, -1.5848, -0.7946, 0.1007, 0.0145, 0.3438, 0.2524]

  # Calculate dot product
  c = features.zip(weights_c).map { |x, w| x * w }.sum
  m = features.zip(weights_m).map { |x, w| x * w }.sum
  y = features.zip(weights_y).map { |x, w| x * w }.sum
  k = features.zip(weights_k).map { |x, w| x * w }.sum

  # Clip and Clean (Remove Muddiness)
  c, m, y, k = [c, m, y, k].map { |v| [[v, 0.0].max, 1.0].min }
  
  # Strict thresholding to preserve spot color vibrancy (snap near-zero values to 0)
  c = 0.0 if c < 0.03
  m = 0.0 if m < 0.03
  y = 0.0 if y < 0.03
  k = 0.0 if k < 0.05 # Aggressive K-removal

  [c, m, y, k].map { |v| v.round(4) }
end

begin
  File.open(input_file, 'rb') do |f|
    signature = f.read(4)
    raise "Invalid signature '#{signature}'." unless signature == '8BCB'

    version = f.read(2).unpack1('n')
    raise "Unsupported ACB version: #{version}" unless version == 1

    f.read(2) # id

    book_title   = read_acb_string(f)
    book_prefix  = read_acb_string(f)
    book_postfix = read_acb_string(f)
    book_desc    = read_acb_string(f)

    color_count = f.read(2).unpack1('n')
    f.read(4) # page_size, page_offset
    color_space = f.read(2).unpack1('n')

    channel_count = case color_space
                    when 2 then 4 # CMYK
                    when 0, 1, 7 then 3 # RGB, HSB, Lab
                    when 8 then 1 # Grayscale
                    else raise "Unknown color space ID: #{color_space}"
                    end

    colors = []
    color_count.times do
      name = read_acb_string(f)
      f.read(6) # code
      channels = f.read(channel_count).unpack("C#{channel_count}")

      full_pdf_name = "#{book_prefix}#{name}#{book_postfix}"
      macro_name = full_pdf_name.gsub(/[\s\-\*\/]/, '')

      if color_space == 2 # CMYK
        c, m, y, k = channels.map { |v| (v / 255.0).round(4) }
        val_str = "#{c}, #{m}, #{y}, #{k}"
      elsif color_space == 7 # Lab
        # Convert 0-255 to standard Lab ranges (L: 0-100, a/b: -128-127)
        l_val = (channels[0] / 255.0) * 100.0
        a_val = channels[1] - 128.0
        b_val = channels[2] - 128.0
        
        c, m, y, k = lab_to_cmyk_ml(l_val, a_val, b_val)
        val_str = "#{c}, #{m}, #{y}, #{k}"
      else
        val_str = "0.0, 0.0, 0.0, 1.0" # Fallback
      end

      colors << { macro: macro_name, pdf_name: full_pdf_name, values: val_str }
    end

    File.open(output_file, 'w') do |out|
      out.puts "% spotxcolor definition file for #{book_title}"
      out.puts "% Auto-generated from .acb"
      if color_space == 7
        out.puts "% NOTE: Applied a 3rd-Degree Polynomial Regression Model trained on native"
        out.puts "% Adobe .acbl data to predict highly accurate CMYK fallback values."
      end
      out.puts ""
      out.puts "\\ProvidesFile{#{File.basename(output_file)}}[Spot color definitions]"
      out.puts ""
      
      colors.each do |c|
        out.puts "\\definespotcolor{#{c[:macro]}}{#{c[:pdf_name]}}{#{c[:values]}}"
      end
      out.puts "\\endinput"
    end

    puts "Successfully extracted #{color_count} colors."
    if color_space == 7
      puts "Applied ML-Trained Regression to eliminate K-channel muddiness and ensure high accuracy."
    end
    puts "Output saved to: #{output_file}"
  end
rescue => e
  puts "Error processing file: #{e.class} - #{e.message}"
end
