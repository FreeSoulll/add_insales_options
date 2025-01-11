require 'net/http'
require 'json'
require 'uri'
require 'csv'
require_relative './module/csv-file'

class Options
  include CSVFile

  USERNAME = '1b84a5dde4d3e0f270c038d7563adfae'
  PASSWORD = '1e4341d659661999b9d9352528f5d283'
  DOMAIN = 'https://myshop-cpk446.myinsales.ru'
  OPTIONS = 'https://myshop-cpk446.myinsales.ru/admin/accessories.json'
  INPUT_FILE = 'volk.csv'
  OUTOUT_FILE = 'volk2.csv'

  def init
    @options_id = []
    @product_options = []
    @all_products = get_products
    #puts @all_products
    #@products = JSON.parse(get_products)
    #puts @products
    #
    #@products = get_products

    read_csv(INPUT_FILE, OUTOUT_FILE)

    # Добавляем опции в магазин
    add_options(@all_modifications)

    # получаем продукты с опциями из файла в таком виде {:title=>"Поводок Патронус", :options=>["Длина", "Карабины", "Добавить ручку-ухват у карабина", "Вес вашей собаки"]}
    #puts @product_options

    # получаем опции в таком виде {"Тип застежки"=>4199575}
    #puts @options_id

    add_options_to_product
  end

  def default_connection(cur_body, url)
    uri = URI.parse(url)
    header = { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' }
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, header)
    request.basic_auth USERNAME, PASSWORD
    request.body = cur_body.to_json
    response = https.request(request)
    JSON.parse(response.body)
  end

  def get_request(url, params={})
    uri = URI.parse(url)

    uri.query = URI.encode_www_form(params)

    header = { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' }
    
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true if uri.scheme == 'https'
    
    request = Net::HTTP::Get.new(uri.path, header)
    request.basic_auth USERNAME, PASSWORD

    response = https.request(request)
    
    response.body
  end

  # Добавляем опции в магазин вместе с их значениями
  def add_options(options = {})
    return unless options

    options.each do |key, value|
      option = {
        "accessory": {
          "name": "#{key}",
          "max_count": 1,
          "min_count": 1,
          "permalink": "#{key}"
        }
      }

      response = default_connection(option, OPTIONS)

      #собираем все опции в виде название-id
      @options_id << { response['name'] => response['id'] }
      
      value.split('///').each do |item|
        price = extract_value(item) || 0
        name = item.split('=').first
        add_options_values(name, price, response['id'])
      end
    end
  end

  def add_options_values(title, price, id)
    add_accessory_value = {
      "accessory_value": {
        "name": title,
        "price": price
      }
    }

    default_connection(add_accessory_value, "#{DOMAIN}/admin/accessories/#{id}/values.json")
  end

  def extract_value(input_string)
    # Используем регулярное выражение для поиска значения после =+
    match = input_string.match(/=\+(\d+)/)
  
    if match
      # Извлекаем первое совпадение группы (число после =+)
      value = match[1]
      puts "Extracted value: #{value}"
      return value.to_i # Вернуть число в виде целого числа
    else
      puts "No value found after +=."
      return nil
    end
  end

  def add_options_to_product
    @all_products.each do |product|
      current_product = @product_options.find { |hash| hash[:title] == product[:title] }

      if current_product
        product_id = product[:id]
        options = current_product[:options]

        options.each do |option|
          select_option = @options_id.select{|item| item[option]}.first
          product_option = {
            "product_accessory_link": {
              "accessory_id": select_option[option]
            }
          }
      
          default_connection(product_option, "#{DOMAIN}/admin/products/#{product_id}/product_accessory_links.json")
          puts "Добавлена опция - #{option} для товара - #{current_product[:title]}"
        end
      end
    end
  end

  def get_products
    products = []
    index = 1
    have_products = true

    while have_products
      url = "#{DOMAIN}/admin/products.json?per_page=200&page=#{index}"
      uri = URI.parse(url)

      # Создание HTTP объекта и выполнения запроса с авторизацией
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')

      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(USERNAME, PASSWORD)

      response = http.request(request)

      # Проверка статуса ответа и вывод содержимого
      if response.is_a?(Net::HTTPSuccess)
        response_products = JSON.parse(response.body, symbolize_names: true)

        have_products = false if response_products.count < 1

        if response_products.count > 0
          products.concat(response_products)
          index += 1
        end
      else
        puts "Failed to retrieve products data: #{response.code} #{response.message}"
      end
    end
    products
  end
end

test = Options.new
test.init