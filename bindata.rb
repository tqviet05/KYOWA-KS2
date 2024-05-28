# require 'bindata'

# class KS2Format < BinData::Record
#   endian :little
#   string :dev, read_length: 256

#   array :channels, read_until: :eof do
#     string :name, read_length: 40
#     int32 :index_a
#     float :coef_a
#     float :coef_b
#     string :unit, read_length: 10
#     float :cal_coef
#     float :offset
#     string :range, read_length: 20
#     string :lpf_info, read_length: 20
#     string :hpf_info, read_length: 20
#   end

#   string :datetime, read_length: 16
#   int64 :sample_count

#   array :data, read_until: :eof do
#     float :value_a
#   end
# end

require 'bindata'
require 'pry'

file = File.open('example.ks2', 'rb')

class StringNumber < BinData::String
  # def value_to_binary_string(val)
  #   p 'value_to_binary_string'
  #   clamp_to_length(val)
  # end

  def read_and_return_value(io)
    p 'read_and_return_value'
    len = eval_parameter(:read_length) || eval_parameter(:length) || 0
    io.readbytes(len).strip.to_i
  end

  # def sensible_default
  #   p 'sensible_default'
  #   ""
  # end
end

class StringStrip < BinData::String
  def read_and_return_value(io)
    p 'read_and_return_value'
    len = eval_parameter(:read_length) || eval_parameter(:length) || 0
    io.readbytes(len).delete('"').strip
  end
end

class FileHeader < BinData::Record
  endian :little

  string_strip :file_id, read_length: 20, trim_padding: true
  string_strip :file_version, read_length: 10, trim_padding: true
  string_strip :file_title, read_length: 44, trim_padding: true
  string_number :num_recorded_chs, read_length: 8
  string_number :num_individual_info_chs, read_length: 8
  string_number :sampling_frequency, read_length: 16
  string_strip :sampling_frequency_unit, read_length: 12, trim_padding: true
  string_strip :recorded_data_type, read_length: 10, trim_padding: true
  string_strip :data_type, read_length: 12, trim_padding: true
  string_number :num_data_blocks, read_length: 14
  string_strip :num_can_ids, read_length: 10
  string_strip :created_language, read_length: 12, trim_padding: true
  string_strip :variable_header_size, read_length: 14, trim_padding: true
  string_number :data_header_size, read_length: 14
  string_number :data_footer_size, read_length: 14
  string_number :variable_footer_size, read_length: 14
  string :reserved, read_length: 24, trim_padding: true
end
class GeneralInfo < BinData::Record
  endian :little

  uint8  :broad, check_value: lambda { value == 1 }
  uint8  :detail
  uint16 :n_byte
  uint8  :flag
  choice :data, selection: :detail do 
    stringz      4,  read_length: lambda { n_byte - 2 }  # 04 Comment
    uint8        44                                      # 2C The number of digital input CHs
    string       45, read_length: lambda { n_byte - 2 }  # 2D Item name
    string_strip 46, read_length: lambda { n_byte - 2 }  # 2E Details of items
    uint8        47                                      # 2F Measuring mode
    stringz      54, read_length: lambda { n_byte - 2 }  # 36 Start trigger pattern
    stringz      55, read_length: lambda { n_byte - 2 }  # 37 End trigger pattern
    double       56                                      # 38 Start trigger level
    double       57                                      # 39 End trigger level
    stringz      58, read_length: lambda { n_byte - 2 }  # 3A Start trigger slope
    stringz      59, read_length: lambda { n_byte - 2 }  # 3B End trigger slope
    string       60, read_length: lambda { n_byte - 2 }  # 3C Digital CH name
    string       61, read_length: lambda { n_byte }      # 3D CAN-ID information
    string       62, read_length: lambda { n_byte }      # 3E CAN-ID condition
    string       63, read_length: lambda { n_byte - 2 }  # 3F CAN communication condition
    uint8        64                                      # 40 LSB/MSB of CAN-ID
    uint8        65                                      # 41 How to extract CAN-CH  condition
    int8         66                                      # 42 Unit code type
    string       67, read_length: lambda { n_byte - 2 }  # 43 Type of the number of body bytes of body section
    string       68, read_length: lambda { n_byte - 2 }  # 44 Start trigger level in physical value
    string       69, read_length: lambda { n_byte - 2 }  # 45 End trigger level in physical value
    string       70, read_length: lambda { n_byte - 2 }  # 46 CAN-CH condition
  end

  class IndividualInfo < BinData::Record
    endian :little

    uint8  :broad, check_value: lambda { value == 2 }
    uint8  :detail
    uint16 :n_byte
    uint8  :flag
    choice :data, selection: :detail do
      float        3                                      # 03 Conversion coefficient A to physical value
      float        4                                      # 04 Conversion coefficient B to physical value
      stringz      5, read_length: lambda { n_byte - 2 }  # 05 Unit character string
      int8         6                                      # 06 Unit code
      float        8                                      # 08 CAL coefficient
      float       12                                      # 0C Offset
      int8        48                                      # 30 Ch No.
      stringz     49, read_length: lambda { n_byte - 2 }  # 31 Ch name
      stringz     50, read_length: lambda { n_byte - 2 }  # 32 Card type
      stringz     51, read_length: lambda { n_byte - 2 }  # 33 Range
      stringz     52, read_length: lambda { n_byte - 2 }  # 34 CAL
      stringz     53, read_length: lambda { n_byte - 2 }  # 35 LPF
      stringz     54, read_length: lambda { n_byte - 2 }  # 36 HPF
      stringz     55, read_length: lambda { n_byte - 2 }  # 37 A/D conversion full scale
      stringz     56, read_length: lambda { n_byte - 2 }  # 38 CH mode
      stringz     57, read_length: lambda { n_byte - 2 }  # 39 Gage factor
      stringz     58, read_length: lambda { n_byte - 2 }  # 3A Gage resistance
      stringz     59, read_length: lambda { n_byte - 2 }  # 3B Lead wire resistance
      stringz     60, read_length: lambda { n_byte - 2 }  # 3C BV voltage
      stringz     61, read_length: lambda { n_byte - 2 }  # 3D Standard resistance value
      stringz     62, read_length: lambda { n_byte - 2 }  # 3E Poisson’s ratio
      stringz     63, read_length: lambda { n_byte - 2 }  # 3F CH No.
      stringz     64, read_length: lambda { n_byte - 2 }  # 40 Card name
      stringz     65, read_length: lambda { n_byte - 2 }  # 41 Mode
      int8        66                                      # 42 The number of decimals
      double      67                                      # 43 Engineering unit conversion cofficient A
      double      68                                      # 44 Engineering unit conversion cofficient B
      double      69                                      # 45 CAL coefficient
      double      70                                      # 46 Offset
      stringz     71, read_length: lambda { n_byte - 2 }  # 47 Low pass digital fillter
      stringz     72, read_length: lambda { n_byte - 2 }  # 48 Zero value
      stringz     73, read_length: lambda { n_byte - 2 }  # 49 High pass digital filter
      stringz     74, read_length: lambda { n_byte - 2 }  # 4A Reserve
    end
  end
  class HeaderData < BinData::Record
    endian :little

    uint8  :broad, check_value: lambda { value == 10 }
    uint8  :detail
    uint16 :n_byte
    uint8  :flag
    choice :data, selection: :detail do 
      string      3,  read_length: lambda { n_byte - 2 }  # 03 Year – Month - Day, Hour - Minute – Second
      int64      29                                       # 1D Size of data footer section
      int64      30                                       # 1E The number of data per CH of the item
      int64      31                                       # 1F Describes actual start trigger position with data
      int64      32                                       # 20 Describes actual end trigger position with data
      string     33, read_length: lambda { n_byte - 2 }   # 21 Upper/lower limit of graph scale (*1)
      string     34, read_length: lambda { n_byte - 2 }   # 22 Up to 5 items of MAX/MIN data (*3)
      string     35, read_length: lambda { n_byte - 2 }   # 23 400 data around MAX/MIN (*4)
      int64      36                                       # 24 MAX/MIN generating point of 5 MAX/MIN upper data (*5)
    end
  end

  def RecordData < BinData::Record
    endian :little

    uint8  :broad, check_value: lambda { value == 11 }
    uint8  :detail

  end

  class FooterData << BinData::Record
    endian :little

    uint8  :broad, check_value: lambda { value == 12 }
    uint8  :detail


  end

  def read_data
    raise 'Is not info header' unless broad == 1
  end

  # string :data, read_length: lambda { |n_byte| n_byte - 2}
end


# data =FileHeader.read(file)
# data.num_recorded_chs
file.seek("6fa".hex,0)
a = file.read(700)
p a
BinData::trace_reading do
  GeneralInfo.read(a)
end
