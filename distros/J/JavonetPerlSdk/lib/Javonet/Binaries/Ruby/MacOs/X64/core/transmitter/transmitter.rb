require 'ffi'
require 'os'
require_relative 'transmitter_wrapper'

class Transmitter

  def self.send_command(message_byte_array, message_byte_array_len)
    message = FFI::MemoryPointer.new(:uchar, message_byte_array_len, true)
    message.put_array_of_uchar(0, message_byte_array)
    response_byte_array_len = TransmitterWrapper.SendCommand(message, message_byte_array_len)
    if response_byte_array_len > 0
      response = FFI::MemoryPointer.new(:uchar, response_byte_array_len, true)
      TransmitterWrapper.ReadResponse(response, response_byte_array_len)
      response_byte_array = response.get_array_of_uchar(0, response_byte_array_len)
      return response_byte_array
    elsif response_byte_array_len == 0
      error_message = "Response is empty"
      raise Exception.new error_message
    else
      error_message = get_native_error
      raise Exception.new "Javonet native error code: " + response_byte_array_len.to_s + ". " + error_message
    end
  end

  def self.activate_with_license_file()
    return activate()
  end

  def self.activate_with_credentials(licenseKey)
    return activate(licenseKey)
  end

  def self.activate_with_credentials_and_proxy(licenseKey, proxyHost, proxyUserName, proxyPassword)
    return activate(licenseKey, proxyHost, proxyUserName, proxyPassword)
  end

  private_class_method def self.activate(licenseKey = "", proxyHost = "", proxyUserName = "", proxyUserPassword = "")
    activation_result = TransmitterWrapper.Activate(licenseKey, proxyHost, proxyUserName, proxyUserPassword)
    if activation_result < 0
      error_message = get_native_error
      raise Exception.new "Javonet activation result: " + activation_result.to_s + ". Native error message: " + error_message
    else
      return activation_result
    end
  end

  def self.get_native_error
    TransmitterWrapper.GetNativeError
  end

  def self.set_config_source(configPath)
    set_config_result = TransmitterWrapper.SetConfigSource(configPath)
    if set_config_result < 0
      error_message = get_native_error
      raise Exception.new "Javonet set config source result: " + set_config_result.to_s + ". Native error message: " + error_message
    else
      return set_config_result
    end
  end
end
