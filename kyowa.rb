# frozen_string_literal: true

require 'csv'
require 'optionparser'
require 'pry'

class KS2
  HEAD_SEEK = 256
  INFO_SEEK = 6
  FIX_CH = 16
  RDTP_DICT = {
    0 => 'c',
    1 => 's',
    2 => 'l',
    3 => 'e',
    4 => 'E',
    5 => 'C',
    6 => 'S',
    7 => 'L',
    8 => 'q',
    9 => 'Q'
  }.freeze

  attr_reader :name, :ch_n, :unit, :ch_range, :ch_lpf, :ch_hpf, :datetime, :samp_n

  def initialize(filename, block_no = 1)
    @filename = filename
    @block_no = block_no
    @fid = File.open(@filename, 'rb')
    @delta = 0

    step_get_info
    read
    binding.pry
  end

  def self.main
    puts <<~MESSAGE
      A Ruby code to access Kyowa KS2 file.
      Copyright (C) 2018 ZC. Fang (zhichaofang@sjtu.org)
      This program comes with ABSOLUTELY NO WARRANTY.
      This is free software, and you are welcome to redistribute it under certain conditions.
    MESSAGE

    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options] filename"
      opts.on('-s', '--save', 'Export data file') do |save|
        options[:save] = save
      end
      opts.on('-o', '--output FILE', 'Export file name') do |output|
        options[:output] = output
      end
      opts.on('-p', '--plot', 'Plot measured data') do |plot|
        options[:plot] = plot
      end
      opts.on('-c', '--channels CHANNELS', Array, 'Channels') do |channels|
        options[:channels] = channels.map(&:to_i)
      end
      opts.on_tail('-h', '--help', 'Show this message') do
        puts opts
        exit
      end
    end
    parser.parse!

    filename = ARGV[0]
    unless filename
      puts parser
      exit
    end

    ks2 = KS2.new(filename)

    ks2.save_as_csv(options[:output] || "#{File.basename(filename, '.*')}.csv") if options[:save]

    return unless options[:plot]

    ks2.plot_data(options[:channels])
  end

  def step_get_info
    16.times do |i|
      line = @fid.readline.delete('"').strip
      case i
      when 0
        @dev = line.encode('UTF-8')
      when 2
        @name = line.encode('UTF-8')
      when 3
        @ch_n = line.to_i
      when 4
        @ch_ncan = line.to_i - @ch_n
      when 5
        @fs = line.to_i
      when 9
        @block_n = line.to_i
      when 12
        @variable_header = line.to_i
      when 13
        @data_header = line.to_i
      end
    end
  end

  def check_flag(delta)
    @fid.seek(HEAD_SEEK + delta)
    tmp = @fid.read(2)
    return [0, 0] if tmp.nil?

    tmp.unpack('CC')
  end

  def check_flg_n_bytes(parent, child)
    return 4 if [62, 70].include?(child) && parent == 1
    return 4 if child == 35 && parent == 16
    return 4 if child == 1 && parent == 17
    return 8 if child == 2 && parent == 17
    return 8 if child == 25 && parent == 18

    2
  end

  def get_n_bytes(parent, child)
    flg_n_bytes = check_flg_n_bytes(parent, child)

    n_bytes = case flg_n_bytes
              when 4
                @fid.read(4).unpack1('I').to_i - 2
              when 8
                @fid.read(8).unpack1('Q').to_i - 2
              else
                @fid.read(2).unpack1('S').to_i - 2
              end

    case child
    when 61, 62, 70
      rdtp = @fid.read(2).unpack1('s')
    when 63
      rdtp = @fid.read(4).unpack1('i')
    else
      @fid.seek(1, 1)
      rdtp = RDTP_DICT[@fid.read(1).unpack1('C')]
    end

    [n_bytes, rdtp]
  end

  def getSizeOf(rdtp)
    return 1 if [8, 9].include?(rdtp)
    return 2 if [1, 6].include?(rdtp)
    return 4 if [2, 3, 4, 5].include?(rdtp)

    8
  end

  def read
    parent, child = check_flag(@delta)

    # Đọc các phần header có thể thay đổi
    while [1, 2].include?(parent)
      n_bytes, rdtp = get_n_bytes(parent, child)
      @delta = read_data(n_bytes, rdtp, parent, child, @delta)
      parent, child = check_flag(@delta)
    end

    # Đọc dữ liệu
    flg = parent
    while flg <= parent
      n_bytes, rdtp = get_n_bytes(parent, child)

      @delta = read_data(n_bytes, rdtp, parent, child, @delta)
      parent, child = check_flag(@delta)
      break if flg > 18
    end
  end

  def read_data(n_bytes, rdtp, parent, child, delta)
    flg_n_bytes = 2 # Default value

    case parent
    when 1
      flg_n_bytes = 4 if [62, 70].include?(child)
    when 2
      case child
      when 48
        # Chỉ số kênh hợp lệ
        @ch_index = @fid.read(2 * @ch_n).unpack('s*')
        puts "Chỉ số kênh hợp lệ: #{@ch_index}"
      when 3
        # Hệ số A (độ dốc)
        @coef_a = @fid.read(4 * @ch_n).unpack('f*')
        puts "Hệ số A: #{@coef_a}"
      when 4
        # Hệ số B (độ lệch)
        @coef_b = @fid.read(4 * @ch_n).unpack('f*')
        puts "Hệ số B: #{@coef_b}"
      when 5
        # Đơn vị kênh
        @unit = @fid.read(10 * @ch_n).unpack('A10' * @ch_n)
        puts "Đơn vị kênh: #{@unit}"
      when 8
        # Hệ số hiệu chuẩn
        @cal_coef = @fid.read(4 * @ch_n).unpack('f*')
        puts "Hệ số hiệu chuẩn: #{@cal_coef}"
      when 12
        # Độ lệch
        @offset = @fid.read(4 * @ch_n).unpack('f*')
        puts "Độ lệch: #{@offset}"
      when 49
        # Tên kênh
        @ch_name = @fid.read(40 * @ch_n).unpack('A40' * @ch_n)
        puts "Tên kênh: #{@ch_name}"
      when 51
        # Phạm vi
        @ch_range = @fid.read(20 * @ch_n).unpack('A20' * @ch_n)
        puts "Phạm vi kênh: #{@ch_range}"
      when 53
        # Bộ lọc thấp
        @ch_lpf = @fid.read(20 * @ch_n).unpack1('A20' * @ch_n)
        puts "Thông tin bộ lọc thấp kênh: #{@ch_lpf}"
      when 54
        # Bộ lọc cao
        @ch_hpf = @fid.read(20 * @ch_n).unpack1('A20' * @ch_n)
        puts "Thông tin bộ lọc cao kênh: #{@ch_hpf}"
      end
    when 16
      case child
      when 3
        # Thời gian bắt đầu (yyyymmddhhmmss)
        datetime = @fid.read(16).strip
        @datetime = DateTime.strptime(datetime, '%Y%m%d%H%M%S')
        puts "Thời gian bắt đầu: #{@datetime}"
      when 30
        # Số lượng mẫu
        @samp_n = @fid.read(8).unpack1('Q')
        puts "Số lượng mẫu: #{@samp_n}"
      when 35
        flg_n_bytes = 4
      end
    when 17
      # Đọc dữ liệu
      print 'Đang đọc dữ liệu...'
      flg_n_bytes = 4 if child == 1
      flg_n_bytes = 8 if child != 1
      sizeof = getSizeOf(rdtp)
      n_bytes_per_sample = @ch_n * sizeof
      length = n_bytes / n_bytes_per_sample.to_f
      puts 'Cảnh báo: Số lượng mẫu không khớp!' if length.round != @samp_n
      if n_bytes <= 512 * 1024 * 1024
        @raw = @fid.read(n_bytes).unpack("#{rdtp}*").each_slice(@ch_n).to_a
      else
        n0 = 512 * 1024 * 1024 / n_bytes_per_sample
        n = n_bytes / (n0 * n_bytes_per_sample)
        n1 = @samp_n - n * n0
        @raw = Array.new(@samp_n) { Array.new(@ch_n, 0) }
        n.times do |i|
          print n - i
          data_block = @fid.read(n0 * n_bytes_per_sample).unpack(rdtp).each_slice(@ch_n).to_a
          @raw[i * n0, n0] = data_block
        end
        print 0
        if n1.positive?
          data_block = @fid.read(n1 * n_bytes_per_sample).unpack(rdtp).each_slice(@ch_n).to_a
          @raw[n * n0, n1] = data_block
        end
      end
      puts 'Hoàn thành.'
    when 18
      flg_n_bytes = 8 if child == 25
    end

    delta += case flg_n_bytes
             when 4
               INFO_SEEK + 2 + n_bytes
             when 8
               INFO_SEEK + 6 + n_bytes
             else
               INFO_SEEK + n_bytes
             end

    delta
  end

  def convert_data
    @data = Array.new(@raw.length) { Array.new(@ch_n, 0.0) }

    @raw.each_with_index do |row, i|
      row.each_with_index do |value, j|
        @data[i][j] = @coef_a[j] * value + @coef_b[j]
      end
    end
  end

  def save(ext = nil, savename = nil)
    savename = "#{@filename.gsub(File.extname(@filename), '')}.mat" if savename.nil?

    case ext
    when '.mat'
      save_matlab(savename)
    when '.csv'
      save_as_csv(savename)
    else
      puts "Saving in #{ext} format has not been implemented yet."
    end
  end

  def save_matlab(savename)
    puts 'Saving data in mat format...'

    data_hash = {
      'name': @name,
      'datetime': @datetime,
      'fs': @fs,
      'samp_n': @samp_n,
      'ch_n': @ch_n,
      'chIndex': @ch_index,
      'ch_name': @ch_name,
      'chUnit': @unit,
      'range': @ch_range,
      'coef_a': @coef_a,
      'coef_b': @coef_b,
      'calCoef': @cal_coef,
      'meaZero': @offset,
      'LPFinfo': @ch_lpf,
      'HPFinfo': @ch_hpf,
      'RAW': @raw
    }

    File.open(savename, 'w') do |file|
      file.write(data_hash.to_s)
    end

    puts "Data saved to #{savename}."
  end

  def save_as_csv(savename)
    CSV.open(savename, 'wb') do |csv|
      csv << ['Device: ' + @dev]
      csv << ['Project: ' + @name]
      csv << ['Number channels: '] + [@ch_n]
      csv << ['Number samples: '] + [@samp_n]
      csv << ['Frequency samples: '] + [@fs]
      csv << ['Number blocks: '] + [@block_n]
      csv << ['Time: '] + [@datetime.strftime('%F %T.%L')]
      csv << ['Units: '] + @unit
      # csv << ['Coefficients_A: '] + @coef_a
      # csv << ['Coefficients_B: '] + @coef_b
      csv << ['Ranges: '] + @ch_range
      csv << ['Calibrations: '] + @cal_coef
      csv << ['Offsets: '] + @offset
      csv << ['LPFinfo: '] + [@ch_lpf]
      csv << ['HPFinfo: ' ]+ [@ch_hpf]
      csv << ['Channels: ']
      
      csv << ['Time'] + @ch_name  # Header row
      convert_data
      @data.each_with_index do |row, i|
        csv << [(i * (1.0 / @fs)).round(@fs.to_s.size)] + row
      end
    end

    puts "Data saved as CSV: #{savename}"
  end

  def to_s
    <<-STRING.strip
      KS2 data object
      (#{@dev}, #{@name}, #{@datetime},
      N ch: #{@ch_n}, fs: #{@fs} Hz, N block: #{@block_n}, N samples: #{@samp_n})
    STRING
  end
end

KS2.main if __FILE__ == $PROGRAM_NAME
